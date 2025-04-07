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

#Null Resource to Waite for nodes to be ready
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
    EOT
  }
}


#Get the OIDC provider URL for the EKS cluster
# This is used to create IAM roles for service accounts
# and to configure the EKS cluster to use the OIDC provider
# This is necessary for the EBS CSI driver to work

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "oidc" {
  url = replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")
}