variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "karpenter-demo"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.29"
}

variable "karpenter_version" {
  description = "Karpenter version"
  type        = string
  default     = "1.6.3"
}

variable "node_instance_types" {
  description = "List of instance types for the initial node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  description = "Desired number of nodes in the initial node group"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum number of nodes in the initial node group"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes in the initial node group"
  type        = number
  default     = 10
}

variable "enable_spot_instances" {
  description = "Enable spot instances in Karpenter NodePool"
  type        = bool
  default     = true
}

variable "karpenter_cpu_limit" {
  description = "CPU limit for Karpenter NodePool"
  type        = number
  default     = 1000
}

variable "node_expire_after" {
  description = "Time after which nodes expire (in hours)"
  type        = string
  default     = "720h" # 30 days
}
