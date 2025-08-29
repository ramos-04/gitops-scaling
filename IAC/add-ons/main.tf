resource "kubernetes_manifest" "argocd_addons_app_of_apps" {
# This Terraform resource block defines a Kubernetes manifest.
# The "kubernetes_manifest" resource allows you to manage arbitrary Kubernetes resources
# that are not directly supported by dedicated Terraform Kubernetes resources.
# In this case, it's used to create an ArgoCD Application resource.

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"  # Specifies the API version of the Kubernetes resource.
    kind       = "Application"           # Specifies the kind of Kubernetes resource being created. Here, it's an "Application", which is a custom resource definition (CRD) provided by ArgoCD.
    metadata = {
                  name      = "argocd-bootstrap-application"
                  namespace = var.argocd_namespace  # The Kubernetes namespace where this ArgoCD Application will be created.
                  labels = {
                             name = "argocd-bootstrap-application"
                           }
               }

  spec = {                  # The 'spec' block defines the desired state of the ArgoCD Application.
      project = "default"
      source = {
                  repoURL        = var.gitops_repo_url     # The URL of the Git repository where the Kubernetes manifests for this application are stored.
                  targetRevision = var.gitops_repo_target_revision
                  path           = "gitops/argocd/base"    # The specific path within the Git repository where the application's manifests reside.
                  kustomize      =  {} # This tells ArgoCD to use Kustomize
               }
      destination = {
                        server    = "https://kubernetes.default.svc" # The API server URL of the target Kubernetes cluster.
                        namespace = "default"    # The target Kubernetes namespace where the resources defined by this application will be deployed.
                    }

      
      syncPolicy = {    # The 'syncPolicy' block defines how ArgoCD should synchronize the application with the Git repository.
        automated = {
                          prune    = true  # If set to true, ArgoCD will automatically delete resources from the cluster that are no longer defined in the Git repository. This helps prevent orphaned resources.
                          selfHeal = true
                          # If set to true, ArgoCD will automatically detect and correct any manual changes
                          # made to the application's resources in the cluster that deviate from the Git state.
                          # It will revert them back to the desired state defined in Git.
                    }
        syncOptions = [
          "CreateNamespace=true"
        ]
      }
    }
  }
}

