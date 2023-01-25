#!/bin/bash

# Simple dev flow
docker build . -f Dockerfile.ubuntu -t bencdr/podman:ubuntu
docker push bencdr/podman:ubuntu
coder templates push -y
coder stop podman-ubuntu -y

sleep 3
# Start or update
if [[ $(coder update podman-ubuntu) == "Workspace isn't outdated!" ]]; then
    coder start podman-ubuntu -y
fi
coder ssh podman-ubuntu