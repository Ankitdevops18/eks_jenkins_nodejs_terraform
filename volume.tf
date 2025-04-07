# #Create IAM Policy:
# resource "aws_iam_policy" "ebs_csi_policy" {
#   name   = "AmazonEKS_EBS_CSI_Driver_Policy"
#   policy = data.aws_iam_policy_document.ebs_csi.json
# }

# data "aws_iam_policy_document" "ebs_csi" {
#   statement {
#     actions = [
#       "ec2:CreateVolume",
#       "ec2:AttachVolume",
#       "ec2:DetachVolume",
#       "ec2:DeleteVolume",
#       "ec2:DescribeAvailabilityZones",
#       "ec2:DescribeInstances",
#       "ec2:DescribeVolumes",
#       "ec2:DescribeTags",
#       "ec2:CreateTags",
#       "ec2:DeleteTags"
#     ]
#     resources = ["*"]
#   }
# }

# #Create IAM Role for ServiceAccount:
# resource "aws_iam_role" "ebs_csi_driver_role" {
#   name = "AmazonEKS_EBS_CSI_DriverRole"

#   assume_role_policy = data.aws_iam_policy_document.ebs_trust.json
# }

# resource "aws_iam_openid_connect_provider" "eks" {
#   client_id_list  = ["sts.amazonaws.com"]
#   thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0c199e2e4"]
#   url             = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
# }


# data "aws_iam_policy_document" "ebs_trust" {
#   statement {
#     effect = "Allow"
#     principals {
#       type        = "Federated"
#       identifiers = [aws_iam_openid_connect_provider.eks.arn]
#     }
#     actions = ["sts:AssumeRoleWithWebIdentity"]

#     condition {
#       test     = "StringEquals"
#       variable = "${replace(aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer, "https://", "")}:sub"
#       values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
#     }
#   }
# }

# resource "aws_iam_role_policy_attachment" "ebs_attach" {
#   policy_arn = aws_iam_policy.ebs_csi_policy.arn
#   role       = aws_iam_role.ebs_csi_driver_role.name
# }

# data "aws_iam_role" "ebs_csi_driver_role" {
#   name = "AmazonEKS_EBS_CSI_DriverRole"
# depends_on = [ aws_iam_role.ebs_csi_driver_role ]
# }

# output "ebs_csi_driver_role_arn" {
#   value = aws_iam_role.ebs_csi_driver_role.arn
# }

# # #Attach IAM Role to EBS CSI Addon:
# # resource "aws_eks_addon" "ebs_csi_driver" {
# #   cluster_name             = aws_eks_cluster.eks_cluster.name
# #   addon_name               = "aws-ebs-csi-driver"
# #   addon_version            = "v1.30.0-eksbuild.1"  # match your EKS version
# #   service_account_role_arn = aws_iam_role.ebs_csi_driver_role.arn
# #   depends_on = [
# #     aws_eks_cluster.eks_cluster,
# #     aws_iam_role_policy_attachment.eks_node_policy
# #   ]
# # }