# Fetch default VPC ID
data "aws_vpc" "default" {
  default = true
}

# Fetch all subnets in the default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Fetch default security group of the default VPC
data "aws_security_group" "default_vpc_sg" {
  vpc_id = data.aws_vpc.default.id
  name   = "default"
}

# Tag for EKS cluster discovery
resource "aws_ec2_tag" "eks_subnets_cluster" {
  for_each    = toset(data.aws_subnets.default.ids)
  resource_id = each.key
  key         = "kubernetes.io/cluster/${var.cluster_name}"
  value       = "owned"
}

# EKS Cluster Module
module "eks_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31" # Or your desired version

  vpc_id                   = data.aws_vpc.default.id
  subnet_ids               = data.aws_subnets.default.ids
  control_plane_subnet_ids = data.aws_subnets.default.ids
  cluster_endpoint_public_access  = true  # Explicitly enable public access for EKS control plane
  cluster_endpoint_private_access = false # Explicitly disable private access for EKS control plane

  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
      configuration_values = jsonencode({
        env = {
          WARM_IP_TARGET = "1"
        }
      })
    }
  }
  
  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Project     = "gitops-scaling-project"
  }
   

}

# IAM Role for the EKS Managed Node Group
resource "aws_iam_role" "eks_managed_node_group" {
  name = "${var.cluster_name}-mng-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Project     = "gitops-scaling-project"
  }
}

# Attach policies to the EKS Managed Node Group Role
resource "aws_iam_role_policy_attachment" "eks_mng_worker_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_managed_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_mng_cni_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_managed_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_mng_ecr_attach" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_managed_node_group.name
}

# AWS EKS Managed Node Group Resource
resource "aws_eks_node_group" "initial_mng" {
  cluster_name    = module.eks_cluster.cluster_name
  node_group_name = "${var.cluster_name}-initial-mng"
  node_role_arn   = aws_iam_role.eks_managed_node_group.arn
  subnet_ids      = data.aws_subnets.default.ids # Use default VPC subnets

  instance_types = ["m5.large"] # Small, cost-effective instance type
  disk_size      = 20

  scaling_config {
    desired_size = 2  
    min_size     = 1  
    max_size     = 3  
  
  }

  # Ensure the node group depends on the cluster being active
  depends_on = [
    module.eks_cluster.cluster_id
  ]

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
    Project     = "gitops-scaling-project"
    # Tagging for EKS cluster association (mandatory for managed node groups)
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  }
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = kubernetes_namespace.argocd.metadata[0].name
  version    = "5.50.0" # Use a specific, compatible version for stability
  create_namespace = true

  depends_on = [kubernetes_namespace.argocd]
}

resource "null_resource" "wait_for_argocd_ready" {
  depends_on = [helm_release.argocd]

  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting for ArgoCD server deployment to be ready (max 300s)..."
      kubectl wait --for=condition=Available deployment/argocd-server --namespace argocd --timeout=300s
      echo "ArgoCD server deployment is ready."
    EOT
    interpreter = ["bash", "-c"]
  }
}


data "kubernetes_secret" "argocd_initial_password" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  depends_on = [helm_release.argocd, null_resource.wait_for_argocd_ready]
}

data "kubernetes_service" "argocd_server" {
  metadata {
    name      = "argocd-server"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }
  depends_on = [helm_release.argocd, null_resource.wait_for_argocd_ready]
}