variable "image" {
  description = "Full container image reference including tag. Set by the CI pipeline via -var flag."
  type        = string
}

variable "replica_count" {
  description = "Number of pod replicas for the dev deployment."
  type        = number
  default     = 1
}

variable "ingress_host" {
  description = "Hostname for the dev Ingress rule."
  type        = string
  default     = "dev.helloworld.example.com"
}

variable "ingress_class" {
  description = "Ingress class name."
  type        = string
  default     = "nginx"
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig file. Defaults to the standard location."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubectl context name (or EKS ARN) pointing at the target cluster."
  type        = string
}
