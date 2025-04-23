# EKS Node.js Application Setup with Terraform and Jenkins

This repository contains the setup for deploying a Node.js application on an Amazon EKS cluster using Terraform for infrastructure provisioning, Jenkins for CI/CD, and a blue-green deployment strategy for seamless application updates.

## Directory Structure

- **`Projects/EKS_Nodejs_BG/Terraform/`**: Contains Terraform scripts for provisioning the EKS cluster and related Kubernetes resources.
- **`Nodejs-Sample/`**: Contains the Node.js application code, Kubernetes manifests for blue-green deployment, and Jenkins pipeline configuration.

Nodejs-Sample Repo URL : https://github.com/Ankitdevops18/nodejs-sample
Terraform Repo URL     : https://github.com/Ankitdevops18/eks_jenkins_nodejs_terraform
---

# Commands you need to run to test this whole set up 

1. Clone Terraform & Source Code Repo 
2. Run below comands in terraform repo directory

   terraform init
   terraform plan
   terraform apply --auto-

3. You will get jenkins url as part of the terraform output
4. Hit the jenkins url & login with below credentials
   user : admin
   pwd: admin
  
4. Go to Nodejs-sample Repo, make a change & push to master branch
5. A build must be triggered in Jenkins Pipeline Job - "Nodejs-CI-CD"
6. Wait for the build to finish 
7. You'll find Node-js service Loadbalancer URL in the output - hit that URL on browser to see the latest deployment
8. To test Blue-Green strategy :
   1. Go to Jenkinsfile in Nodejs-sample Repo
   2. In the below environment block , keep SWITCH_TRAFFIC as false to test Green cluster
           environment {
               SWITCH_TRAFFIC = "false"
               IMAGE_NAME = 'hello-node-app'
               DOCKER_REGISTRY = 'ankitofficial1821'
               IMAGE_TAG = '1.0.0'
               IMAGE_FULL_NAME = "docker.io/${DOCKER_REGISTRY}/${IMAGE_NAME}:${IMAGE_TAG}"
               KUBECONFIG = "/var/jenkins_home/.kube/config"
            }
   
   3. To Test blue or green cluster - run below command in the locak to get loadbalancer URLs of respective Cluster : 
         kubect get svc -n nodejs-app
   4. Hit the endpoint URL to get the Node Js application output
   5. Once the testing is done, to Switch the traffic to Green cluster & remove blue - set SWITCH_TRAFFIC flag to true
   6. This would remove blue cluster & switch traffic to green cluster on the main nodejs-service

## Terraform Setup


### Steps to Provision EKS Cluster & Jenkins NodeJs CICD pipeline 

1. Navigate to the Terraform directory:
   ```bash
   cd Projects/EKS_Nodejs_BG/Terraform/

2. Initialize Terraform:

   terraform init

3. Apply the Terraform configuration:

   terraform apply --auto-approve

This will provision below resources:
1. A VPC Network 
2. An EKS cluster and necessary Kubernetes resources. 
3. Install Jenkins in a Pod as part of a Ststefulset inside K8s Cluster using helm.
4. Create a Node Js CICD pipeline inside Jenkins
5. Create a github webhook to trigger deployment as soon as any change is made in the source code repo. 



## Jenkins Setup

### Files in jenkins

Dockerfile: Custom Jenkins image with pre-installed tools:

nerdctl and containerd for container management.
Docker, kubectl, AWS CLI, Node.js, and npm for CI/CD tasks.
commons-compress library for Jenkins plugins.
Jenkins Pipeline (Jenkinsfile):

### Stages:
Checkout: Clones the Node.js application repository.
Install: Installs dependencies using npm install.
Test: Runs tests using npm test.
Build Docker Image: Builds the application Docker image.
Push to Docker Hub: Pushes the image to Docker Hub.
Deploy to Target Color: Deploys the application to the blue or green environment.
Switch Traffic & Cleanup: Switches traffic to the new environment and cleans up the old deployment.



# Blue-Green Deployment Strategy
## Overview
The blue-green deployment strategy ensures zero downtime during application updates by maintaining two environments (blue and green). Traffic is switched between these environments using Kubernetes services.

## Files in k8s
blue-deploy.yaml: Deploys the application to the blue environment.
green-deploy.yaml: Deploys the application to the green environment.
service-blue.yaml: Exposes the blue environment.
service-green.yaml: Exposes the green environment.
switch-traffic.yaml: Switches traffic between blue and green environments.

## Workflow
The Jenkins pipeline detects the currently active environment (blue or green).
It deploys the new version of the application to the inactive environment.
Traffic is switched to the updated environment using switch-traffic.yaml.
The old environment is cleaned up.


# Node.js Application

The Node.js application is located in the Nodejs-Sample directory. It is a simple Express.js app that listens on port 3000 and responds with "Hello World from Node.js!".

## Running Locally
   Install dependencies:

   npm install

   Start the application:

   npm start


   Access the application at 

   http://localhost:3000.



# Conclusion
This setup provides a robust CI/CD pipeline for deploying a Node.js application on EKS with a blue-green deployment strategy. It ensures high availability and zero downtime during updates.



