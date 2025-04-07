#Create IAM OIDC Provider for EKS Cluster
resource "aws_iam_openid_connect_provider" "oidc" {
  client_id_list = ["sts.amazonaws.com"]
  thumbprint_list = ["9e99a48a9960b14926bb7f3b02e22da0ecd4e4c1"] # Default thumbprint for AWS
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

#Output the OIDC URL for the EKS cluster
output "eks_oidc_url" {
  value = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

#Create EBS CSI Driver IAM Role
resource "aws_iam_role" "ebs_csi_irsa_role" {
  name = "AmazonEKS_EBS_CSI_Driver_IRSA"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.oidc.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })
}

#Attach Policies to EBS CSI Driver IAM Role
resource "aws_iam_role_policy_attachment" "ebs_csi_policy_attach" {
  role       = aws_iam_role.ebs_csi_irsa_role.name
  policy_arn = var.ebs_csi_policy
  depends_on = [
    aws_iam_role.ebs_csi_irsa_role
  ]
}


#Creating Service Accoint for EBS CSI Driver on EKS Cluster
resource "kubernetes_service_account" "ebs_csi_sa" {
  metadata {
    name      = var.ebs_csi_sa_name
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.ebs_csi_irsa_role.arn
    }
  }
}

#EBS CSI Driver for EKS
resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = var.ebs_csi_chart_version
  namespace  = "kube-system"

  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = var.ebs_csi_sa_name
  }

  set {
    name  = "enableVolumeScheduling"
    value = "true"
  }

  set {
    name  = "enableVolumeResizing"
    value = "true"
  }

  set {
    name  = "enableVolumeSnapshot"
    value = "true"
  }

  set {
    name  = "topology.enable"
    value = "true"
  }

  set {
    name  = "controller.topologyKey"
    value = "topology.ebs.csi.aws.com/zone"
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_node_group,
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cluster_policy,
    kubernetes_service_account.ebs_csi_sa
    ]

}

#Creating Storage Class for EBS CSI Driver
# This storage class will be used by the EBS CSI driver to provision volumes
resource "kubernetes_storage_class" "ebs_csi" {
  metadata {
    name = "ebs-sc"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.aws.com"

  parameters = {
    type = "gp3"
  }

  reclaim_policy        = "Retain"
  volume_binding_mode   = "WaitForFirstConsumer"
  allow_volume_expansion = true  

  allowed_topologies {
    match_label_expressions {
      key    = "topology.ebs.csi.aws.com/zone"
      values = var.availability_zones
    }
  }
}

#Patch Default Storage Class
# This resource will patch the default storage class to set it as non-default
# This is necessary to ensure that the EBS CSI driver is used as the default storage class
resource "null_resource" "storage_class_patch" {
  triggers = {
    cluster_name = aws_eks_cluster.eks_cluster.name
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "Updating kubeconfig..."
      aws eks --region ${var.region} update-kubeconfig --name ${var.cluster_name} --profile ${var.profile}
      if [ $? -ne 0 ]; then
        echo "Failed to update kubeconfig"
        exit 1
      fi
      echo "Kubeconfig updated successfully"

      kubectl patch storageclass gp2 -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
      if [ $? -ne 0 ]; then
        echo "Failed to patch storage class"
        exit 1
      fi
      echo "Storage class patched successfully"
    EOT
  }
  
  depends_on = [
    kubernetes_storage_class.ebs_csi
  ]
}


