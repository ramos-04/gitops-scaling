variable "aws_region" {
  description = "AWS region for the deployment."
  type        = string
  default     = "eu-north-1" 
}

variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
  default     = "gitops-eks-cluster"
}
