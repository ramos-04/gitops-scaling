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

 # store the state file remotely in cloud storage. Configure the details below as per your setup
 backend "s3" {
    bucket       = "<>"
    key          = "<path to state file>"
    region       = "<>"
    use_lockfile = true
              }
}

provider "aws" {
  region = var.aws_region
}

provider "helm" {
  kubernetes {
    host                   = module.eks_cluster.cluster_endpoint
    config_path = "~/.kube/config"
    #cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
    #token                  = var.cluster_auth_token
  }
}

provider "kubernetes" {
  host                   = module.eks_cluster.cluster_endpoint
  config_path = "~/.kube/config"
  #cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
  #token                  = var.cluster_auth_token
}
