---
name: JetBrains Projector containers for Coder
description: Build images and run JetBrains workspaces on the Docker host with no image registry required
tags: [local, docker]
---

# projector-container

Provison JetBrains Projector containers with Coder.

> **Warning** This template may not work for you (see [coder/coder#2621](https://github.com/coder/coder/issues/2621)). Use Coder's [official docs](https://github.com/coder/coder/issues/2621) for projector instead.

![pyCharm in Coder](https://raw.githubusercontent.com/bpmct/coder-templates/main/screenshots/projector-pycharm.png)

This example bundles Dockerfiles with the Coder template, allowing the Docker host to build images itself instead of relying on an external registry.

For large use cases, we recommend building images using CI/CD pipelines and registries instead of at workspace runtime. However, this example is practical for tinkering and iterating on Dockerfiles.

## Requirements

Docker running on the Coder server.

## Getting started

```sh
git clone https://github.com/bpmct/coder-templates.git
cd projector-container
coder templates create
```

## Adding images

Create a Dockerfile (e.g `images/golang.Dockerfile`):

```sh
vim images/go-projects.Dockerfile
```

```Dockerfile
# Start from base image (built on Docker host)
FROM goland:v0.1

# Install everything as root
USER root

# Install go
RUN curl -L "https://dl.google.com/go/go1.18.1.linux-amd64.tar.gz" | tar -C /usr/local -xzvf -

# Setup go env vars
ENV GOROOT /usr/local/go
ENV PATH $PATH:$GOROOT/bin

ENV GOPATH /home/coder/go
ENV GOBIN $GOPATH/bin
ENV PATH $PATH:$GOBIN

# Set back to coder user
USER coder
```

Edit the Terraform template (`main.tf`):

```sh
vim main.tf
```

Edit the validation to include the new image:

```diff
variable "docker_image" {
    description = "What Docker image would you like to use for your workspace?"
    default     = "base"

    # List of images available for the user to choose from.
    # Delete this condition to give users free text input.
    validation {
-       condition     = contains(["intellij", "pycharm", "goland"], var.docker_image)
+       condition     = contains(["intellij", "pycharm", "goland", "go-projects"], var.docker_image)
        error_message = "Invalid Docker image!"
    }
}
```

Bump the image tag to a new version:

```diff
resource "docker_image" "coder_image" {
    name = "coder-base-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
    build {
        path       = "./images/"
        dockerfile = "${var.docker_image}.Dockerfile"
-        tag        = ["coder-${var.docker_image}:v0.1"]
+        tag        = ["coder-${var.docker_image}:v0.2"]
    }

    # Keep alive for other workspaces to use upon deletion
    keep_locally = true
}
```

Update the template:

```sh
coder template update docker-image-builds
```

You can also remove images from the validation list. Workspaces using older template versions will continue using
the removed image until you update the workspace to the latest version.

## Updating images

Edit the Dockerfile (or related assets):

```sh
vim images/idea-u.Dockerfile
```

```diff
FROM jetbrains/projector-idea-u:latest

USER root

# We need CURL to start the Coder agent
RUN sudo apt-get update && sudo apt-get install -y curl

# Install code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Install other base dependencied you need here!

+# Add Java 11
+ RUN sudo apt-get install -y openjdk-11-jre

USER projector-user
```

1. Edit the Terraform template (`main.tf`)

```sh
vim main.tf
```

Bump the image tag to a new version:

```diff
resource "docker_image" "coder_image" {
    name = "coder-base-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
    build {
        path       = "./images/"
        dockerfile = "${var.docker_image}.Dockerfile"
-        tag        = ["coder-${var.docker_image}:v0.1"]
+        tag        = ["coder-${var.docker_image}:v0.2"]
    }

    # Keep alive for other workspaces to use upon deletion
    keep_locally = true
}
```

Update the template:

```sh
coder template update docker-image-builds
```

Optional: Update workspaces to the latest template version

```sh
coder ls
coder update [workspace name]
```

## Extending this template

See the [kreuzwerker/docker](https://registry.terraform.io/providers/kreuzwerker/docker) Terraform provider documentation to
add the following features to your Coder template:

- SSH/TCP docker host
- Build args
- Volume mounts
- Custom container spec
- More

We also welcome all contributions!
