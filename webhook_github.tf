
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


