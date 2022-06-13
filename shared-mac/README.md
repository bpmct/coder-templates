---
name: Develop on a shared Mac
description: Connect a pre-provisioned Mac device and provision system users as workspaces
tags: [dedicated, unix]
---

# mac-mini

This template gives developers access to an existing Mac machine you maintain. Great for 
MacOS-only workloads such as iOS evelopment, XCode, etc.

![Developing an iOS app on a Linux thinkpad](https://raw.githubusercontent.com/bpmct/coder-templates/main/metadata/shared-mac-01.png)

> Developing iOS apps on a remote Mac Mini. Connecting from a Linux Thinkpad as the "client."

To get started, run `coder templates init`. When prompted, select this template. Follow the on-screen instructions to proceed.

## Requirements

You must already have a Mac machine with:

- `coder` installed in `/usr/local/bin`

    - This will be automatically installed in a future version

- SSH server reachable by machine running `coder server`

    - I use [Tailscale](https://tailscale.com) to keep my home network private.

- Optional: [VNC enabled](https://support.apple.com/guide/remote-desktop/set-up-a-computer-running-vnc-software-apdbed09830/mac#:~:text=On%20the%20client%20computer%2C%20choose,VNC%20password%2C%20then%20click%20OK.) for desktop access

## VNC

While I recommend using native IDE over SSH whenever possible, VNC has been great
for iOS simulators, configuring XCode, or other desktop-only applications. Any modern VNC client should work. Use `coder port-forward <workspace-name> --tcp 5900:5900` to forward the VNC server to your `localhost`. 

## TODO

This template is incomplete. The following work is planned:

- Use `coder_agent.dev.init_script` to install the proper Coder 
    version on the host

    - I ran into some initial issues with this, but I think I
    could get it working with `nohup` and some EOFs.

- Optionally create system users based on Coder username

    - should be a template-wide setting so it doesn't
    introduce complexity for a one-user Mac setups
    (ref: ./create_user.sh)
    - delete system user if workspace is being terminated
    - stop proper agent process. Not all of them
