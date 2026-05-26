variable "namespace" {
  description = "Kubernetes namespace to create and deploy into."
  type        = string
}

variable "app_name" {
  description = "Application name used for Kubernetes resource names and labels."
  type        = string
  default     = "helloworld"
}

variable "image" {
  description = "Full container image reference including tag, e.g. ghcr.io/org/repo:sha-abc1234."
  type        = string
}

variable "replica_count" {
  description = "Number of pod replicas."
  type        = number
  default     = 2
}

variable "container_port" {
  description = "Port the application container listens on."
  type        = number
  default     = 8080
}

variable "ingress_host" {
  description = "Hostname for the Ingress rule (DNS must resolve to the ingress controller's LB IP)."
  type        = string
}

variable "ingress_class" {
  description = "Ingress class name (matches the installed ingress controller)."
  type        = string
  default     = "nginx"
}

variable "cpu_request" {
  description = "CPU resource request."
  type        = string
  default     = "50m"
}

variable "memory_request" {
  description = "Memory resource request."
  type        = string
  default     = "64Mi"
}

variable "cpu_limit" {
  description = "CPU resource limit."
  type        = string
  default     = "200m"
}

variable "memory_limit" {
  description = "Memory resource limit."
  type        = string
  default     = "128Mi"
}

variable "env_vars" {
  description = "Key-value pairs injected into the container as environment variables via a ConfigMap."
  type        = map(string)
  default     = {}
}
