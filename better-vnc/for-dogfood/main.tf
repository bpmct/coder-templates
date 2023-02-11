terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.6.10"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.22"
    }
  }
}

locals {
  username = data.coder_workspace.me.owner
}

data "coder_provisioner" "me" {
}

variable "region" {
  type        = string
  description = "Which region to deploy to."
  default     = "us-pittsburgh"
  validation {
    condition     = contains(["us-pittsburgh", "eu-helsinki", "ap-sydney"], var.region)
    error_message = "Region must be one of us-pittsburg, eu-helsinki, or ap-sydney."
  }
}

locals {
  // These are Tailscale IP addresses. Ask Dean or Kyle for help.
  docker_host = {
    ""              = "tcp://100.94.74.63:2375"
    "us-pittsburgh" = "tcp://100.94.74.63:2375"
    "eu-helsinki"   = "tcp://100.117.102.81:2375"
    "ap-sydney"     = "tcp://100.127.2.1:2375"
  }
}

provider "docker" {
  host = lookup(local.docker_host, var.region)
}

data "coder_workspace" "me" {
}

resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"

  login_before_ready     = false
  startup_script_timeout = 180
  startup_script         = <<-EOT
    set -e

    # install and start code-server
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server --version 4.8.3
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &

    /dockerstartup/kasm_default_profile.sh /dockerstartup/vnc_startup.sh /dockerstartup/kasm_startup.sh &
  EOT

  # These environment variables allow you to make Git commits right away after creating a
  # workspace. Note that they take precedence over configuration defined in ~/.gitconfig!
  # You can remove this block if you'd prefer to configure Git manually or using
  # dotfiles. (see docs/dotfiles.md)
  env = {
    GIT_AUTHOR_NAME     = "${data.coder_workspace.me.owner}"
    GIT_COMMITTER_NAME  = "${data.coder_workspace.me.owner}"
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace.me.owner_email}"
    GIT_COMMITTER_EMAIL = "${data.coder_workspace.me.owner_email}"
    VNC_PW              = "password"
  }
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337/?folder=/home/${local.username}"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 5
    threshold = 6
  }
}

resource "coder_app" "kasmvnc" {
  agent_id     = coder_agent.main.id
  slug         = "kasmvnc"
  display_name = "KasmVNC"
  url          = "http://localhost:6901"
  icon         = "https://avatars.githubusercontent.com/u/44181855?s=280&v=4"
  subdomain    = true
  share        = "owner"
  healthcheck {
    url       = "http://localhost:6901"
    interval  = 5
    threshold = 6
  }
}


resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
  # Protect the volume from being deleted due to changes in attributes.
  lifecycle {
    ignore_changes = all
  }
  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace.me.owner
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace.me.owner_id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  # This field becomes outdated if the workspace is renamed but can
  # be useful for debugging or cleaning out dangling volumes.
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}


resource "docker_image" "main" {
  name = "coder-${data.coder_workspace.me.id}"
  build {
    path = "build/."
    build_args = {
      USER = local.username
    }
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "build/*") : filesha1(f)]))
  }
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.main.name
  # Uses lower() to avoid Docker restriction on container names.
  name = "coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
  # Hostname makes the shell more user friendly: coder@my-workspace:~$
  hostname = data.coder_workspace.me.name
  # Use the docker gateway if the access URL is 127.0.0.1
  entrypoint = ["sh", "-c", replace(coder_agent.main.init_script, "/localhost|127\\.0\\.0\\.1/", "host.docker.internal")]
  env        = ["CODER_AGENT_TOKEN=${coder_agent.main.token}"]
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
  volumes {
    container_path = "/home/${local.username}"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace.me.owner
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace.me.owner_id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}
