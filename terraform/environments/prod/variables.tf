variable "image" {
  description = "Full container image reference including tag. Always supplied by the pipeline."
  type        = string
}

variable "replica_count" {
  description = "Number of pod replicas for the prod deployment."
  type        = number
  default     = 2
}

variable "ingress_host" {
  description = "Hostname for the prod Ingress rule."
  type        = string
  default     = "helloworld.example.com"
}

variable "ingress_class" {
  description = "Ingress class name."
  type        = string
  default     = "nginx"
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig file."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubectl context name (or EKS ARN) pointing at the target cluster."
  type        = string
}
