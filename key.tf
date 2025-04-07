resource "tls_private_key" "eks_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "eks_key" {
  key_name   = var.key_name
  public_key = tls_private_key.eks_key.public_key_openssh
}

resource "local_file" "eks_private_key" {
  content              = tls_private_key.eks_key.private_key_pem
  filename             = "${path.module}/${var.key_name}.pem"
  file_permission      = "0400"
  directory_permission = "0755"
}