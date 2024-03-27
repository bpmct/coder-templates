---
name: Develop in a Proxmox LXC
description: Get started with a development environment on Proxmox.
tags: [self-hosted, proxmox, lxc, code-server]
---

# proxmox-vm

## Getting started

Requirements:

- A [Coder](https://github.com/coder/coder) deployment
- A Proxmox deployment
- SSH access between Coder <-> Proxmox
  - I used Tailscale!

```sh
git clone https://github.com/bpmct/coder-templates
cd coder-templates/proxmox-vm

# you'll likely need to change the SSH user details!
# as well as some things about your Proxmox config!
vim main.tf

coder templates create
```
