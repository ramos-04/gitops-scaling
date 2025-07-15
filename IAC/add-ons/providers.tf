terraform {
  required_providers {
    aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
          }
    kubernetes = {
                    source  = "hashicorp/kubernetes"
                    version = "~> 2.23"
                 }

         }
       }

provider "aws" {
                  region = var.aws_region
               }

provider "kubernetes" {
                          host                   = var.cluster_endpoint # endpoint access url of the EKS cluster
                          #cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
                          #token                  = var.cluster_auth_token
                          config_path = "~/.kube/config" # Used for authentication
                      }

