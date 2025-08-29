output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks_cluster.cluster_name
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster."
  value       = module.eks_cluster.cluster_endpoint
}

output "aws_region" {
  description = "AWS region for the deployment."
  value       = var.aws_region
}

output "argocd_namespace" {
  description = "The namespace where ArgoCD is installed."
  value       = kubernetes_namespace.argocd.metadata[0].name
}

output "argocd_helm_release_name" {
  description = "The name of the ArgoCD Helm release."
  value       = helm_release.argocd.name
}

output "argocd_initial_password_secret_name" {
  value = data.kubernetes_secret.argocd_initial_password.metadata[0].name
}

/*
output "cluster_certificate_authority_data" {
  description = "The base64 encoded certificate authority data for the EKS cluster."
  value       = module.eks_cluster.cluster_certificate_authority_data
}

output "cluster_auth_token" {
  description = "Authentication token for the EKS cluster (retrieved via aws_eks_cluster_auth)."
  value       = data.aws_eks_cluster_auth.this.token
  sensitive   = true
}
*/