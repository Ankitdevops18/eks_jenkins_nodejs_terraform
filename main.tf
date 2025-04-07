# Create EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids         = aws_subnet.public_subnets[*].id
    security_group_ids = [aws_security_group.eks_cluster_sg.id]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}

# Create EKS Node Group
resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = var.node_group_name
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = aws_subnet.public_subnets[*].id
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.desired_capacity
    max_size     = var.max_capacity
    min_size     = var.min_capacity
  }

  remote_access {
    ec2_ssh_key               = var.ec2_ssh_key
    source_security_group_ids = [aws_security_group.worker_nodes_sg.id]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_node_policy]
}

data "aws_eks_cluster" "eks_cluster" {
  name = aws_eks_cluster.eks_cluster.name
}

data "aws_eks_cluster_auth" "eks_auth" {
  name = aws_eks_cluster.eks_cluster.name
}

# Security Group for EKS Cluster
resource "aws_security_group" "eks_cluster_sg" {
  vpc_id        = aws_vpc.eks_vpc.id
  description   = "EKS Cluster Security Group"
  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}

resource "aws_security_group_rule" "eks_ingress_rules" {
  for_each      = toset([for p in var.ports : tostring(p)]) # convert to set of strings

  type              = "ingress"
  from_port         = tonumber(each.value)
  to_port           = tonumber(each.value)
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster_sg.id
}

# Security Group for Worker Nodes
resource "aws_security_group" "worker_nodes_sg" {
  vpc_id        = aws_vpc.eks_vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.eks_cluster_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-worker-nodes-sg"
  }
}


# IAM Roles and Policies for Cluster

resource "aws_iam_role" "eks_cluster_role" {
  name = "eks_cluster_role"

  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  for_each   = { for idx, policy in var.cluster_iam_policy : "policy_${idx}" => policy }
  policy_arn = each.value
  role       = aws_iam_role.eks_cluster_role.name
}

data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

# IAM Roles and Policies for Node Group
resource "aws_iam_role" "eks_node_role" {
  name = "eks_node_role"

  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json
}

resource "aws_iam_role_policy_attachment" "eks_node_policy" {
  for_each   = { for idx, policy in var.node_iam_policy: "policy_${idx}" => policy }
  policy_arn = each.value
  role       = aws_iam_role.eks_node_role.name
}


data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = var.ebs_csi_chart_version
  namespace  = "kube-system"
  create_namespace = false

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
    name  = "topologySpreadConstraints.enabled"
    value = true
  }

  set {
    name  = "topologyKey"
    value = "topology.ebs.csi.aws.com/zone"
  }

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_node_group,
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cluster_policy
    ]

}

resource "kubernetes_service_account" "ebs_csi_sa" {
  metadata {
    name      = var.ebs_csi_sa_name
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.eks_node_role.arn
    }
  }
  depends_on = [ helm_release.ebs_csi_driver ]
}


# Adding null resource to run commands after EKS setup
# This null resource will run commands to set up the EKS cluster after it has been created
# and the nodes are ready. It will update the kubeconfig, get the nodes, and install Jenkins using Helm.
# This is useful for automating the setup of the EKS cluster and installing necessary tools.
# Note: Ensure that you have the AWS CLI and Helm installed and configured on your local machine.

resource "null_resource" "post_eks_setup" {
  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_eks_node_group.eks_node_group,
    aws_iam_role_policy_attachment.eks_node_policy,
    aws_iam_role_policy_attachment.eks_cluster_policy
    ]

  provisioner "local-exec" {
    command = <<EOT
      echo "Updating kubeconfig..."
      aws eks --region ${var.region} update-kubeconfig --name ${var.cluster_name} --profile ${var.profile}
      if [ $? -ne 0 ]; then
        echo "Failed to update kubeconfig"
        exit 1
      fi
      echo "Kubeconfig updated successfully"

      echo "Creating Kubernetes namespoce"
      if ! kubectl get ns jenkins > /dev/null 2>&1; then
       kubectl create namespace jenkins
      else
       echo "Namespace 'jenkins' already exists, skipping"
      fi

      echo "Creating Kubernetes secret"
      if ! kubectl get secret jenkins-kubeconfig -n jenkins > /dev/null 2>&1; then
       kubectl create secret generic jenkins-kubeconfig --from-file=config=$HOME/.kube/config -n jenkins
      else
       echo "Secret 'jenkins-kubeconfig' already exists, skipping"
      fi

      echo "Waiting for nodes to be ready..."
      while true; do
        nodes_ready=$(kubectl get nodes --no-headers | grep -c "Ready")
        if [ "$nodes_ready" -gt 0 ]; then
          echo "Nodes are ready"
          break
        else
          echo "Waiting for nodes to be ready..."
          sleep 10
        fi
      done
      echo "Nodes are ready"
      echo "Creating Jenkins image.."
      docker build -t ankitofficial1821/jenkins-with-tools:latest ${path.module}/jenkins
      echo ${var.dockerhub_password} | docker login -u ${var.dockerhub_username} --password-stdin
      docker push ankitofficial1821/jenkins-with-tools:latest
    EOT
  }
}

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
  depends_on = [ null_resource.post_eks_setup ]

  allowed_topologies {
    match_label_expressions {
      key    = "topology.ebs.csi.aws.com/zone"
      values = var.availability_zones
    }
  }
}

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
    null_resource.post_eks_setup,
    kubernetes_storage_class.ebs_csi
  ]
}

data "aws_secretsmanager_secret_version" "docker_password" {
  provider  = aws.personal
  secret_id = "docker_password"
}

data "aws_secretsmanager_secret_version" "github_token" {
  provider  = aws.personal
  secret_id = "github_token"
}

resource "null_resource" "jenkins_config" {
  provisioner "local-exec" {
    command = <<EOT
      echo "Updating kubeconfig..."
      aws eks --region ${var.region} update-kubeconfig --name ${var.cluster_name} --profile ${var.profile}
      if [ $? -ne 0 ]; then
        echo "Failed to update kubeconfig"
        exit 1
      fi
      echo "Kubeconfig updated successfully"

      echo "Installing Jenkins using Helm..."
      helm repo add jenkins https://charts.jenkins.io
      helm repo update
      if ! kubectl get svc jenkins -n jenkins > /dev/null 2>&1; then
        helm install jenkins jenkins/jenkins \
            --namespace jenkins \
            --values ${path.module}/jenkins/jenkins-values.yaml
        if [ $? -ne 0 ]; then
            echo "Failed to install Jenkins"
            exit 1
        fi
        echo "Jenkins installed successfully"
      else
        echo "Jenkins already installed, upgrading.."
        helm upgrade jenkins jenkins/jenkins \
            --namespace jenkins \
            --values ${path.module}/jenkins/jenkins-values.yaml
        if [ $? -ne 0 ]; then
            echo "Failed to upgrade Jenkins"
            exit 1
        fi
      fi

    EOT
  }
  
  depends_on = [
    null_resource.post_eks_setup,
    null_resource.storage_class_patch,
    kubernetes_storage_class.ebs_csi,
    data.aws_secretsmanager_secret_version.docker_password,
    data.aws_secretsmanager_secret_version.github_token
  ]
}

resource "null_resource" "wait_for_lb" {
  provisioner "local-exec" {
    command = <<EOT
      while [ -z "$(kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')" ]; do
        echo "Waiting for Jenkins LoadBalancer to get hostname..."
        sleep 10
      done
    EOT
  }
  depends_on = [
    null_resource.jenkins_config
  ]
}