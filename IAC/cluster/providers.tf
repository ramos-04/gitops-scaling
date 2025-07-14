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
      version = "~> 2.23"
    }

    null = {
      source = "hashicorp/null"
      version = "~> 3.0"
    }


  }
}

provider "aws" {
  region = var.aws_region
}

provider "helm" {
  
  kubernetes {
    host                   = module.eks_cluster.cluster_endpoint
    #cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
    #token                  = var.cluster_auth_token
    config_path = "~/.kube/config"
  }

}

provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  #cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  #token                  = var.cluster_auth_token
  config_path = "~/.kube/config"
}