# resource "helm_release" "jenkins" {
#   name       = "jenkins"
#   namespace  = "jenkins"
#   chart      = "${path.module}/helm/jenkins"

#   values = [
#     file("${path.module}/jenkins/jenkins-values.yaml")
#   ]

#   set {
#     name  = "controller.tag"
#     value = "2.440.1"
#   }

#   set {
#     name  = "controller.JCasC.enabled"
#     value = "true"
#   }

#   depends_on = [
#     aws_eks_cluster.eks_cluster,
#     null_resource.post_eks_setup
#     ]
# }

resource "kubernetes_config_map" "jenkins_jcasc" {
  metadata {
    name      = "jenkins-jcasc-config"
    namespace = "jenkins"
    labels = {
      "jenkins.io/config-type" = "casc"
    }
  }
  data = {
    "jenkins.yaml" = file("${path.module}/jenkins/jenkins.yaml")
  }
  depends_on = [
    null_resource.post_eks_setup,
    local_file.jenkins_config
  ]
}

data "kubernetes_service" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = "jenkins"
  }
  depends_on = [
    null_resource.post_eks_setup,
    null_resource.wait_for_lb,
    kubernetes_config_map.jenkins_jcasc
    ]
}

output "jenkins_url" {
  value = "http://${data.kubernetes_service.jenkins.status.0.load_balancer.0.ingress.0.hostname}"
  description = "Public Jenkins LoadBalancer URL"
}


#Set uo Github Webhook
resource "github_repository_webhook" "jenkins_webhook" {
  repository = var.github_repo_name

  configuration {
    url          = "http://${data.kubernetes_service.jenkins.status.0.load_balancer.0.ingress.0.hostname}/github-webhook/"
    content_type = "json"
    insecure_ssl = true
  }

  events = ["push"]
  active = true
  depends_on = [
    null_resource.wait_for_lb
    ]
}

resource "local_file" "jenkins_config" {
  filename = "${path.module}/jenkins/jenkins.yaml"
  content  = templatefile("${path.module}/jenkins/jenkins.yaml.tmpl", {
    dockerhub_username = var.dockerhub_username
    dockerhub_password = local.dockerhub_password
    github_url        = var.github_repo
    github_branch      = var.github_branch
  })
}


