---
name: Develop on a shared Mac
description: Connect a pre-provisioned Mac device and provision system users as workspaces
tags: [dedicated, unix]
---

# mac-mini

Thie templates gives developers access to an existing Mac machine you maintain.

To get started, run `coder templates init`. When prompted, select this template. Follow the on-screen instructions to proceed.


## Requirements

You must already have a Mac machine with:

- `coder` installed in `/usr/local/bin`

    - This will be automatically installed in a future version

- SSH server reachable by machine running `coder server`

    - I use [Tailscale](https://tailscale.com) to keep my home network private.

- Optional: [VNC enabled](https://support.apple.com/guide/remote-desktop/set-up-a-computer-running-vnc-software-apdbed09830/mac#:~:text=On%20the%20client%20computer%2C%20choose,VNC%20password%2C%20then%20click%20OK.) for desktop access

## TODO

This template is incomplete. The following work is planned:

- Use `coder_agent.dev.init_script` to install the proper Coder 
    version on the host

    - I ran into some initial issues with this, but I think I
    could get it working with `nohup` and some EOFs.

- Optionally create system user based on Coder username

    - should be a template-wide setting so it doesn't
    introduce complexity for a one-user Mac
    (ref: ./create_user.sh)
    - Delete system user if workspace is being terminated
    - Stop proper agent process. Not all of them
