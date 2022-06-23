terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.4.2"
    }
  }
}
variable "mac_user" {
  sensitive = true
}

variable "mac_host" {
  sensitive = true
}


provider "aws" {
  region = var.region
}

data "coder_workspace" "me" {
}

resource "coder_agent" "dev" {
  arch = "amd64"
  auth = "token"
  os   = "darwin"
}

resource "coder_app" "code-server" {
  agent_id      = coder_agent.dev.id
  name          = "VS Code"
  icon          = "${data.coder_workspace.me.access_url}/icon/code.svg"
  url           = "http://localhost:13337"
  relative_path = true
}

resource "coder_app" "novnc" {
  agent_id      = coder_agent.dev.id
  name          = "noVNC"
  icon          = "${data.coder_workspace.me.access_url}/icon/novnc-icon.svg"
  url           = "http://localhost:6080"
  relative_path = true
}

resource "null_resource" "mac-ssh" {
  count = data.coder_workspace.me.start_count == 0 ? 0 : 1
  connection {
    type = "ssh"
    user = var.mac_user
    host = var.mac_host
    # agent = true can also be used, but this was easier
    private_key = file("/root/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      # 1) Start Coder
      "CODER_AGENT_URL=${data.coder_workspace.me.access_url} CODER_AGENT_AUTH=token CODER_AGENT_TOKEN=${coder_agent.dev.token} nohup /usr/local/bin/coder agent &",
      # 2) Gracefully exit "terraform apply"
      # see https://stackoverflow.com/a/36732953
      "sleep 1"
    ]
  }
}

resource "null_resource" "stop-coder-agent" {
  count = data.coder_workspace.me.start_count == 0 ? 1 : 0
  connection {
    type = "ssh"
    user = var.mac_user
    host = var.mac_host
    # agent = true can also be used, but this was easier
    private_key = file("/root/.ssh/id_rsa")
  }

  provisioner "remote-exec" {
    inline = [
      # stop Coder agent
      "kill $(ps -eo pid,pgid,tpgid,args | awk 'NR == 1 || ($3 != -1 && $2 != $3)' | grep \"coder agent\" | awk '{ print $1}')"
    ]
  }
}

