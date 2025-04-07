provider "aws" {
  region     = var.region
  profile    = var.profile
}

provider "aws" {
  alias  = "personal"
  region = var.region
  profile = var.secrets_profile
}

provider "kubernetes" {
  host                   = aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_auth.token
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "github" {
  token = local.github_token
  owner = var.github_owner
}