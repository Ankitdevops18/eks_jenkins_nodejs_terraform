#Setting up EKS Cluster before installing Jenkins - creating secret, namespace and Jenkins Image.
resource "null_resource" "pre_jenkins_setup" {
  depends_on = [
    null_resource.post_eks_setup
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


      echo "Creating Jenkins image.."
      docker build -t ankitofficial1821/jenkins-with-tools:latest ${path.module}/jenkins
      echo ${var.dockerhub_password} | docker login -u ${var.dockerhub_username} --password-stdin
      docker push ankitofficial1821/jenkins-with-tools:latest
    EOT
  }
}

#Pull docker password and github token from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "docker_password" {
  provider  = aws.personal
  secret_id = "docker_password"
}

#Pull github token from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "github_token" {
  provider  = aws.personal
  secret_id = "github_token"
}


#Create jenkins.yaml file using templatefile function
# This file will be used to configure Jenkins using the Configuration as Code (JCasC) plugin
resource "local_file" "jenkins_config" {
  filename = "${path.module}/jenkins/jenkins.yaml"
  content  = templatefile("${path.module}/jenkins/jenkins.yaml.tmpl", {
    dockerhub_username = var.dockerhub_username
    dockerhub_password = local.dockerhub_password
    github_url        = var.github_repo
    github_branch      = var.github_branch
  })
    depends_on = [
        data.aws_secretsmanager_secret_version.docker_password,
        data.aws_secretsmanager_secret_version.github_token
    ]
}

#Create a Kubernetes ConfigMap to store the Jenkins Configuration as Code (JCasC) file
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
    local_file.jenkins_config,
    null_resource.pre_jenkins_setup
  ]
}

#Install Jenkins using Helm
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

      kubectl apply -f ${path.module}/k8s/jenkins-role.yaml
      if [ $? -ne 0 ]; then
        echo "Failed to apply Jenkins Role"
        exit 1
      fi
      echo "Jenkins Role applied successfully"

      kubectl apply -f ${path.module}/k8s/namespace.yaml
      kubectl apply -f ${path.module}/k8s/kaniko_namespace.yaml
      kubectl apply -f ${path.module}/k8s/blue-deploy.yaml
      kubectl apply -f ${path.module}/k8s/service-blue.yaml
      kubectl apply -f ${path.module}/k8s/switch-traffic.yaml
      kubectl create secret generic regcred --from-file=config.json=${path.module}/config.json -n kaniko
      if [ $? -ne 0 ]; then
        echo "Failed to create regcred secret" 
        exit 1
      fi
      echo "regcred secret created successfully" 

    EOT
  }
  
  depends_on = [
    null_resource.pre_jenkins_setup,
    local_file.jenkins_config,
    kubernetes_config_map.jenkins_jcasc,
    null_resource.storage_class_patch
  ]
}


#Wait for Jenkins LoadBalancer to get hostname
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

#Get the Jenkins LoadBalancer service
data "kubernetes_service" "jenkins" {
  metadata {
    name      = "jenkins"
    namespace = "jenkins"
  }
  depends_on = [
    null_resource.wait_for_lb,
    kubernetes_config_map.jenkins_jcasc
    ]
}

#Output the Jenkins LoadBalancer URL
output "jenkins_url" {
  value = "http://${data.kubernetes_service.jenkins.status.0.load_balancer.0.ingress.0.hostname}"
  description = "Public Jenkins LoadBalancer URL"
}

