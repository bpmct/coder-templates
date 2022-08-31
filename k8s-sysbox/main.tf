terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.4.9"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.10"
    }
    k8s = {
      source = "mingfang/k8s"
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
  default     = "coder-on-k8s"
}

provider "kubernetes" {}

data "coder_workspace" "me" {}

# code-server
resource "coder_app" "code-server" {
  agent_id      = coder_agent.dev.id
  name          = "code-server"
  icon          = "/icon/code.svg"
  url           = "http://localhost:13337"
  relative_path = true
}

variable "cvm" {
  type    = bool
  default = true

  description = <<EOF
  Add Docker support?

  Leverages the sysbox container runtime
  https://github.com/nestybox/sysbox
  EOF

}


resource "coder_agent" "dev" {
  os             = "linux"
  arch           = "amd64"
  dir            = "/home/coder"
  startup_script = <<EOF
    #!/bin/sh
    curl -fsSL https://code-server.dev/install.sh | sh
    code-server --auth none --port 13337 &

    sudo dockerd&

    ${var.dotfiles_uri != "" ? "coder dotfiles -y ${var.dotfiles_uri}" : ""}
  EOF
}

variable "disk_size" {
  description = "Disk size (__ GB)"
  default     = 10
}

variable "docker_image" {
  description = <<EOF
  Name of Docker image to pull
  
  e.g codercom/enterprise-base:ubuntu
  EOF
  default     = "codercom/enterprise-base:ubuntu"
}

variable "dotfiles_uri" {
  description = <<-EOF
  Dotfiles repo URI (optional)

  see https://dotfiles.github.io
  EOF
  default     = ""
}

resource "k8s_core_v1_pod" "dev" {
  count = data.coder_workspace.me.start_count
  metadata {
    name      = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
    namespace = var.workspaces_namespace
    annotations = {
      "io.kubernetes.cri-o.userns-mode" = "auto:size=65536"
    }
  }


  spec {
    security_context {
      run_asuser = 1000
      fsgroup    = 1000
    }
    runtime_class_name = var.cvm ? "sysbox-runc" : null
    containers {
      command = ["sh", "-c", coder_agent.dev.init_script]
      name    = "dev"
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.dev.token
      }
      image = var.docker_image
      volume_mounts {
        mount_path = "/home/coder"
        name       = "home-directory"
      }
    }
    volumes {
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
