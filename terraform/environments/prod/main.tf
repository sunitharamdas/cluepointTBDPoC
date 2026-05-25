terraform {
  required_version = ">= 1.10"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kube_context
}

module "app" {
  source = "../../modules/k8s-app"

  namespace      = "helloworld-prod"
  app_name       = "helloworld"
  image          = var.image
  replica_count  = var.replica_count
  ingress_host   = var.ingress_host
  ingress_class  = var.ingress_class
  cpu_request    = "100m"
  memory_request = "128Mi"
  cpu_limit      = "500m"
  memory_limit   = "256Mi"

  env_vars = {
    APP_ENV = "prod"
  }
}
