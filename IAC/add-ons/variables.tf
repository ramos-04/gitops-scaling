variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "cluster_endpoint" {
  description = "Endpoint of the EKS cluster."
  type        = string
}

variable "argocd_namespace" {
  description = "namespace of the argocd"
  type        = string
}

variable "aws_region" {
  description = "AWS region."
  type        = string
}

variable "gitops_repo_url" {
  description = "URL of your GitOps repository."
  type        = string
}

variable "gitops_repo_target_revision" {
  description = "Target revision (branch, tag, or commit) for the GitOps repository."
  type        = string
  default     = "HEAD"
}

