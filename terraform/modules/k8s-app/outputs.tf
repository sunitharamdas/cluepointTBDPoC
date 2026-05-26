output "namespace" {
  description = "The Kubernetes namespace created for the application."
  value       = kubernetes_namespace.this.metadata[0].name
}

output "deployment_name" {
  description = "Name of the Kubernetes Deployment."
  value       = kubernetes_deployment.this.metadata[0].name
}

output "service_name" {
  description = "Name of the Kubernetes Service."
  value       = kubernetes_service.this.metadata[0].name
}

output "ingress_host" {
  description = "Hostname configured on the Ingress resource."
  value       = var.ingress_host
}
