FROM codercom/enterprise-base:ubuntu

USER root

RUN apt-get update
RUN apt-get install -y apt-transport-https gnupg jq

# Install kubectl
RUN curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && apt-get install -y kubectl

# Install helm
RUN curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install gcloud
RUN curl -fsSLo /usr/share/keyrings/cloud.google.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" |   tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    apt-get update && apt-get install -y google-cloud-sdk

# Install AWS CLI
RUN pip3 install awscli

# Install Terraform
RUN wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/hashicorp.list && \
    apt-get update && apt-get install terraform

# Install Tilt CLI
RUN curl -fsSL https://raw.githubusercontent.com/tilt-dev/tilt/master/scripts/install.sh | bash

# Install Okteto CLI
RUN curl https://get.okteto.com -sSfL | sh

# Install Garden CLI
ARG GARDEN_VERSION=0.12.52
RUN wget https://github.com/garden-io/garden/releases/download/$GARDEN_VERSION/garden-$GARDEN_VERSION-linux-amd64.tar.gz && \
    tar -xvf garden-$GARDEN_VERSION-linux-amd64.tar.gz && \
    mv linux-amd64/garden /usr/local/bin/garden

USER coder