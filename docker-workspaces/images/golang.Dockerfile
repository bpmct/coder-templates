ARG CODER_BASE_TAG=latest
# Start from base image (built on Docker host)
FROM coder-base:${CODER_BASE_TAG}

# Run everything as root
USER root

# Install go
RUN curl -L "https://dl.google.com/go/go1.18.2.linux-armv6l.tar.gz" | tar -C /usr/local -xzvf -

# Setup go env vars
ENV GOROOT /usr/local/go
ENV PATH $PATH:$GOROOT/bin

ENV GOPATH /home/coder/go
ENV GOBIN $GOPATH/bin
ENV PATH $PATH:$GOBIN

# Install goreleaser
RUN echo 'deb [trusted=yes] https://repo.goreleaser.com/apt/ /' | tee /etc/apt/sources.list.d/goreleaser.list
RUN apt-get update && apt-get install goreleaser -y

# Set back to coder user
USER coder

# Set back to coder user
USER coder
