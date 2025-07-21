terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.37"
    }
    null = {
      source = "hashicorp/null"
      version = "~> 3.0"
    }
  }

 # store the state file remotely in cloud storage. Configure the details below as per your setup
 backend "s3" {
    bucket       = ""
    key          = "" 
    region       = ""
    use_lockfile = true
              }
}

provider "aws" {
  region = var.aws_region
}

provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.cluster_endpoint
    #config_path = "~/.kube/config"
    cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster_auth_token.token
  }
}

provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  #config_path = "~/.kube/config"
  cluster_ca_certificate = base64decode(module.eks_cluster.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster_auth_token.token
}
