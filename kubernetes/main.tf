terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.3.1"
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

resource "coder_agent" "go" {
  os   = "linux"
  arch = "amd64"
  dir  = "/home/vscode"
}

resource "coder_agent" "java" {
  os   = "linux"
  arch = "amd64"
  dir  = "/home/vscode"
}

resource "coder_agent" "ubuntu" {
  os   = "linux"
  arch = "amd64"
  dir  = "/home/vscode"
}

variable "api_token" {
  description = <<EOF
  API token for web app.

  More info at: https://example.com/docs/admin/tokens
  EOF
  default     = ""
}

variable "disk_size" {
  description = "Disk size (__ GB)"
  default     = 10
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
      name    = "go"
      image   = "mcr.microsoft.com/vscode/devcontainers/go:1"
      command = ["sh", "-c", coder_agent.go.init_script]
      security_context {
        run_as_user = "1000"
      }
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.go.token
      }
      env {
        name  = "API_TOKEN"
        value = var.api_token
      }
      volume_mount {
        mount_path = "/home/vscode"
        name       = "home-directory"
      }
    }
    container {
      name    = "java"
      image   = "mcr.microsoft.com/vscode/devcontainers/java"
      command = ["sh", "-c", coder_agent.java.init_script]
      security_context {
        run_as_user = "1000"
      }
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.java.token
      }
      env {
        name  = "API_TOKEN"
        value = var.api_token
      }
      volume_mount {
        mount_path = "/home/vscode"
        name       = "home-directory"
      }
    }
    container {
      name    = "ubuntu"
      image   = "mcr.microsoft.com/vscode/devcontainers/base:ubuntu"
      command = ["sh", "-c", coder_agent.ubuntu.init_script]
      security_context {
        run_as_user = "1000"
      }
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.ubuntu.token
      }
      env {
        name  = "API_TOKEN"
        value = var.api_token
      }
      volume_mount {
        mount_path = "/home/vscode"
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
