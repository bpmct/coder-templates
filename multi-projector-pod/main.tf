terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.4.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.10"
    }
  }
}

variable "use_kubeconfig" {
  type        = bool
  sensitive   = true
  description = <<-EOF
  Use host kubeconfig? (true/false)

  Set this to false if the Coder host is itself running as a Pod on the same
  Kubernetes cluster as you are deploying workspaces to.

  Set this to true if the Coder host is running outside the Kubernetes cluster
  for workspaces.  A valid "~/.kube/config" must be present on the Coder host. This
  is likely not your local machine unless you are using `coder server --dev.`

  EOF
}

variable "workspaces_namespace" {
  type        = string
  sensitive   = true
  description = "The namespace to create workspaces in (must exist prior to creating workspaces)"
  default     = "coder-workspaces"
}

provider "kubernetes" {
  # Authenticate via ~/.kube/config or a Coder-specific ServiceAccount, depending on admin preferences
  config_path = var.use_kubeconfig == true ? "~/.kube/config" : null
}

data "coder_workspace" "me" {}


resource "coder_agent" "dev" {
  os             = "linux"
  arch           = "amd64"
  dir            = "/home/coder"
  startup_script = <<EOF
    #!/bin/sh
    
    # Start code-server
    code-server --auth none --port 13337 &

    # Configure and run JetBrains IDEs

    # Assumes you have IntelliJ (/opt/intellij),
    # PyCharm (/opt/pycharm), and pip3 installed in
    # your image and the "coder" user has filesystem
    # permissions for "/opt/*"
    # ex. https://github.com/bpmct/coder-templates/blob/main/multi-intellij/Dockerfile
    pip3 install projector-installer --user
    /home/coder/.local/bin/projector --accept-license 
    
    /home/coder/.local/bin/projector config add intellij1 /opt/idea --force --use-separate-config --port 9001 --hostname localhost
    /home/coder/.local/bin/projector run intellij1 &

    /home/coder/.local/bin/projector config add intellij2 /opt/idea --force --use-separate-config --port 9002  --hostname localhost
    /home/coder/.local/bin/projector run intellij2 &

    /home/coder/.local/bin/projector config add pycharm1 /opt/idea --force --use-separate-config --port 9003  --hostname localhost
    /home/coder/.local/bin/projector run pycharm1 &

    /home/coder/.local/bin/projector config add pycharm2 /opt/idea --force --use-separate-config --port 9004  --hostname localhost
    /home/coder/.local/bin/projector run pycharm2 &

    ${var.dotfiles_uri != "" ? "coder dotfiles -y ${var.dotfiles_uri}" : ""}
  EOF
}

# code-server
resource "coder_app" "code-server" {
  agent_id = coder_agent.dev.id
  name     = "code-server"
  icon     = "/icon/code.svg"
  url      = "http://localhost:13337"
}

resource "coder_app" "intellij1" {
  agent_id = coder_agent.dev.id
  name     = "IntelliJ1"
  icon     = "/icon/intellij.svg"
  url      = "http://localhost:9001"
}

resource "coder_app" "intellij2" {
  agent_id = coder_agent.dev.id
  name     = "IntelliJ2"
  icon     = "/icon/intellij.svg"
  url      = "http://localhost:9002"
}

resource "coder_app" "pycharm1" {
  agent_id = coder_agent.dev.id
  name     = "PyCharm"
  icon     = "/icon/pycharm.svg"
  url      = "http://localhost:9003"
}

resource "coder_app" "pycharm2" {
  agent_id = coder_agent.dev.id
  name     = "PyCharm1"
  icon     = "/icon/pycharm.svg"
  url      = "http://localhost:9004"
}

variable "disk_size" {
  description = "Disk size (__ GB)"
  default     = 10
}

variable "dotfiles_uri" {
  description = <<-EOF
  Dotfiles repo URI (optional)

  see https://dotfiles.github.io
  EOF
  default     = ""
}

resource "kubernetes_pod" "main" {
  count = data.coder_workspace.me.start_count
  depends_on = [
    kubernetes_persistent_volume_claim.home-directory
  ]
  metadata {
    name      = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
    namespace = var.workspaces_namespace
  }
  spec {
    security_context {
      run_as_user = 1000
      fs_group    = 1000
    }
    container {
      name    = "dev"
      image   = "bencdr/intellij-pycharm-projector@sha256:8e9c4b4d670ce227b80ae8e3f3c84209192f6c0895e30755f119a2cfddd2b2eb"
      command = ["sh", "-c", coder_agent.dev.init_script]
      security_context {
        run_as_user = "1000"
      }
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.dev.token
      }
      volume_mount {
        mount_path = "/home/coder"
        name       = "home-directory"
      }
    }
    volume {
      name = "home-directory"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home-directory.metadata.0.name
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "home-directory" {
  metadata {
    name      = "coder-pvc-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
    namespace = var.workspaces_namespace
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${var.disk_size}Gi"
      }
    }
  }
}
