# Alternative configuration that reuses existing node IAM role
# Uncomment this configuration and comment out the main.tf karpenter module
# if you want to reuse an existing node IAM role

/*
module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name    = local.cluster_name
  cluster_version = var.kubernetes_version

  # EKS Managed Node Group with existing role
  eks_managed_node_groups = {
    initial = {
      instance_types = ["t3.medium"]

      min_size     = 1
      max_size     = 3
      desired_size = 1

      iam_role_additional_policies = {
        AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }
    }
  }

  tags = local.tags
}

module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name = module.eks.cluster_name

  # Reuse existing node IAM role
  create_node_iam_role = false
  node_iam_role_arn    = module.eks.eks_managed_node_groups["initial"].iam_role_arn

  # Since the nodegroup role will already have an access entry
  create_access_entry = false

  tags = local.tags
}
*/
