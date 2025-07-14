resource "kubernetes_manifest" "argocd_addons_app_of_apps" {
  
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "argocd-bootstrap-application"
      namespace = var.argocd_namespace
      labels = {
        name = "argocd-bootstrap-application"
      }
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.gitops_repo_url
        targetRevision = var.gitops_repo_target_revision
        path           = "gitops/argocd/base"
        kustomize      =  {} # This tells ArgoCD to use Kustomize
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }

      
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true
        }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }
}

