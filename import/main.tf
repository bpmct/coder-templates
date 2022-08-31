terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.4.9"
    }
    tailscale = {
      source  = "davidsbond/tailscale"
      version = "0.12.2"
    }
  }
}

variable "os" {
  default = "linux"
  validation {
    condition = contains([
      "linux",
      "darwin",
      "windows",
    ], var.os)
    error_message = "Invalid OS."
  }
}

variable "arch" {
  default = "amd64"
  validation {
    condition = contains([
      "amd64",
      "arm64",
      "armv7",
    ], var.arch)
    error_message = "Invalid arch."
  }
}

resource "coder_agent" "main" {
  os   = var.os
  arch = var.arch
  auth = "token"
}

data "coder_workspace" "me" {
}

resource "local_sensitive_file" "startup_script" {
  content         = <<EOF
export CODER_AGENT_TOKEN=${coder_agent.main.token}
${coder_agent.main.init_script}
  EOF
  filename        = "/tmp/${data.coder_workspace.me.id}.sh"
  file_permission = "0755"
}

data "external" "create_gist" {
  depends_on = [
    local_sensitive_file.startup_script
  ]

  program = ["bash", "${path.module}/create-gist.sh", data.coder_workspace.me.id]

}

resource "null_resource" "workspace" {
  count = data.coder_workspace.me.start_count
  depends_on = [
    data.external.create_gist
  ]

  # Always run
  triggers = {
    always_run = "${timestamp()}"
  }
}

resource "coder_metadata" "idk" {

  count = data.coder_workspace.me.start_count


  resource_id = null_resource.workspace[0].id
  item {
    key   = "type"
    value = null
  }
  item {
    key       = "init command"
    value     = "curl ${data.external.create_gist.result.url} | sh"
    sensitive = true
  }
}
