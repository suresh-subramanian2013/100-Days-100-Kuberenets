################################################################################
# Cluster
################################################################################

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster"
  value       = module.eks.cluster_arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_endpoint" {
  description = "Endpoint for your Kubernetes API server"
  value       = module.eks.cluster_endpoint
}

output "cluster_id" {
  description = "The ID of the EKS cluster. Note: currently a value is returned only for local EKS clusters created on Outposts"
  value       = module.eks.cluster_id
}

output "cluster_name" {
  description = "The name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = module.eks.cluster_oidc_issuer_url
}

output "cluster_platform_version" {
  description = "Platform version for the EKS cluster"
  value       = module.eks.cluster_platform_version
}

output "cluster_status" {
  description = "Status of the EKS cluster. One of `CREATING`, `ACTIVE`, `DELETING`, `FAILED`"
  value       = module.eks.cluster_status
}

output "cluster_primary_security_group_id" {
  description = "Cluster security group that was created by Amazon EKS for the cluster"
  value       = module.eks.cluster_primary_security_group_id
}

################################################################################
# Karpenter
################################################################################

output "karpenter_irsa_arn" {
  description = "The Amazon Resource Name (ARN) specifying the Karpenter IRSA role"
  value       = module.karpenter.irsa_arn
}

output "karpenter_role_name" {
  description = "The name of the Karpenter node IAM role"
  value       = module.karpenter.role_name
}

output "karpenter_role_arn" {
  description = "The Amazon Resource Name (ARN) specifying the Karpenter node IAM role"
  value       = module.karpenter.role_arn
}

output "karpenter_instance_profile_name" {
  description = "Name of the instance profile"
  value       = module.karpenter.instance_profile_name
}

output "karpenter_queue_arn" {
  description = "The ARN of the SQS queue"
  value       = module.karpenter.queue_arn
}

output "karpenter_queue_name" {
  description = "The name of the created Amazon SQS queue"
  value       = module.karpenter.queue_name
}

output "karpenter_queue_url" {
  description = "The URL for the created Amazon SQS queue"
  value       = module.karpenter.queue_url
}

################################################################################
# Additional
################################################################################

output "configure_kubectl" {
  description = "Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig"
  value       = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name}"
}

output "test_karpenter" {
  description = "Commands to test Karpenter functionality"
  value = <<-EOT
    # Scale up the test deployment
    kubectl scale deployment inflate --replicas 5

    # Check deployment status
    kubectl get deployment inflate

    # Check pod status
    kubectl get pods -o wide

    # Check nodes
    kubectl get nodes

    # Monitor Karpenter logs
    kubectl logs -f -n karpenter -l app.kubernetes.io/name=karpenter -c controller

    # Scale down
    kubectl scale deployment inflate --replicas 0
  EOT
}
