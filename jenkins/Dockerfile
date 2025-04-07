FROM jenkins/jenkins:lts

USER root

# Install Docker, Kubectl, AWS CLI, Node.js, npm
RUN apt-get update && apt-get install -y \
    curl gnupg2 lsb-release apt-transport-https ca-certificates software-properties-common \
    docker.io \
    unzip \
    awscli \
    && curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Add Jenkins user to Docker group
RUN usermod -aG docker jenkins

USER jenkins