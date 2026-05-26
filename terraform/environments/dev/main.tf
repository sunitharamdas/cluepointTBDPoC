terraform {
  required_version = ">= 1.10"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}

# ---------------------------------------------------------------------------
# Provider – targets the pre-existing EKS cluster.
# Credentials are injected via environment variables in CI
# (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY or OIDC role assumption).
# Locally, ensure ~/.kube/config is populated with:
#   aws eks update-kubeconfig --region us-east-1 --name <cluster-name>
# ---------------------------------------------------------------------------
provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

module "app" {
  source = "../../modules/k8s-app"

  namespace      = "helloworld-dev"
  app_name       = "helloworld"
  image          = var.image
  replica_count  = var.replica_count
  ingress_host   = var.ingress_host
  ingress_class  = var.ingress_class
  cpu_request    = "50m"
  memory_request = "64Mi"
  cpu_limit      = "200m"
  memory_limit   = "128Mi"

  env_vars = {
    APP_ENV = "dev"
  }
}
