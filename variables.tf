variable "profile" {
  description = "The AWS profile where the EKS cluster will be deployed."
  type        = string
}

variable "secrets_profile" {
  description = "The AWS profile where the EKS cluster will be deployed."
  type        = string
}

variable "region" {
  description = "The AWS region where the EKS cluster will be deployed."
  type        = string
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for the public subnets."
  type        = list(string)
}

variable "availability_zones" {
  description = "A list of Availability Zones for the public subnets."
  type    = list(string)
}


variable "cluster_name" {
  description = "The name of the EKS cluster."
  type        = string
}

variable "node_group_name" {
  description = "The name of the EKS node group."
  type        = string
}

variable "node_instance_type" {
  description = "The EC2 instance type for the nodes."
  type        = string
}

variable "desired_capacity" {
  description = "The desired number of worker nodes."
  type        = number
}

variable "max_capacity" {
  description = "The maximum number of worker nodes."
  type        = number
}

variable "min_capacity" {
  description = "The minimum number of worker nodes."
  type        = number
}

variable "ec2_ssh_key" {
  description = "The name of the SSH key pair to use for accessing worker nodes."
  type        = string
}

variable "ports" {
    description = "Ingress Ports to open"
    type        = list(number)
}

variable "cluster_iam_policy" {
  description = "IAM policies to attach to the EKS cluster role."
  type        = list(string)
}
variable "node_iam_policy" {
  description = "IAM policies to attach to the EKS node group role."
  type        = list(string)
}

variable "ebs_csi_policy" {
  description = "IAM policies to attach to the EBS CSI driver role."
  type        = string
}

variable "key_name" {
  description = "The name of the key pair to use for SSH access to the worker nodes."
  type        = string
}

variable "ebs_csi_addon_name" {
  description = "The Name of EBS CSI Driver."
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token"
  type        = string
  sensitive   = true
  default     = " "
}

variable "github_owner" {
  description = "GitHub org/user that owns the repo"
  type        = string
}
variable "github_repo" {
  description = "GitHub repo name"
  type        = string
}
variable "github_branch" {
  description = "GitHub branch name"
  type        = string
  default     = "master"
}

variable "dockerhub_username" {
  description = "Docker Hub Username"
  type        = string
}

variable "dockerhub_password" {
  description = "Docker Hub Password or PAT"
  type        = string
  sensitive   = true
  default     = " "
}

variable "github_repo_name" {
  description = "GitHub Repo name"
  type        = string
}

locals {
  dockerhub_password = jsondecode(data.aws_secretsmanager_secret_version.docker_password.secret_string)["password"]
  github_token    = jsondecode(data.aws_secretsmanager_secret_version.github_token.secret_string)["password"]
}

variable "ebs_csi_chart_version" {
  description = "EBS CSI Helm Chart Version"
  type        = string
}

variable "ebs_csi_sa_name" {
  description = "EBS CSI Service Account Name"
  type        = string
}
