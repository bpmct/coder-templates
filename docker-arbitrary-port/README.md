---
name: Develop in Docker
description: Develop inside Docker containers using your local daemon
tags: [local, docker]
icon: /icon/docker.png
---

# docker-arbitrary-port

An example template that uses a `coder_app` + ephemeral parameters to allow a user to "share" a port on their workspace with other users. This is bit of a workaround since we eventually want to port sharing as an optional feature.

[See the demo](./demo.mov)

## Editing the image

Edit the `Dockerfile` and run `coder templates push` to update workspaces.

## code-server

`code-server` is installed via the `startup_script` argument in the `coder_agent`
resource block. The `coder_app` resource is defined to access `code-server` through
the dashboard UI over `localhost:13337`.

## Extending this template

See the [kreuzwerker/docker](https://registry.terraform.io/providers/kreuzwerker/docker) Terraform provider documentation to
add the following features to your Coder template:

- SSH/TCP docker host
- Registry authentication
- Build args
- Volume mounts
- Custom container spec
- More

We also welcome contributions!
