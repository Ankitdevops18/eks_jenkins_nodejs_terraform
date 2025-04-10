FROM jenkins/jenkins:lts


USER root


# Install nerdctl and containerd
RUN apt-get update && \
    apt-get install -y curl containerd jq wget && \
    wget https://github.com/containerd/nerdctl/releases/latest/download/nerdctl-full-2.0.4-linux-amd64.tar.gz && \  
    tar -xvzf nerdctl-full-2.0.4-linux-amd64.tar.gz -C /usr/local

RUN chmod +x /usr/local/bin/nerdctl && \
    chmod +x /usr/local/bin/buildkitd


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

# Install commons-compress (used by nodejs plugin)
RUN mkdir -p /usr/share/jenkins/lib && \
    curl -L https://repo1.maven.org/maven2/org/apache/commons/commons-compress/1.21/commons-compress-1.21.jar -o /usr/share/jenkins/lib/commons-compress.jar


# Add Jenkins user to Docker group for access to host Docker daemon
RUN usermod -aG docker jenkins && usermod -aG root jenkins
