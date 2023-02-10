terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.5.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.10"
    }
  }
}

provider "kubernetes" {
}

data "coder_workspace" "me" {}

variable "os" {
  description = "Operating system"
  validation {
    condition     = contains(["ubuntu", "fedora"], var.os)
    error_message = "Invalid zone!"
  }
  default = "ubuntu"
}

resource "coder_agent" "dev" {
  os             = "linux"
  arch           = "amd64"
  dir            = "/home/podman"
  startup_script = <<EOF
    #!/bin/sh
    curl -fsSL https://code-server.dev/install.sh | sh
    code-server --auth none --port 13337 &

    # Run once to avoid unnecessary warning: "/" is not a shared mount
    podman ps
  EOF
}

# code-server
resource "coder_app" "code-server" {
  agent_id = coder_agent.dev.id
  name     = "code-server"
  icon     = "/icon/code.svg"
  url      = "http://localhost:13337"
}

resource "kubernetes_pod" "dev" {
  count = data.coder_workspace.me.start_count
  metadata {
    name      = "coder-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}"
    namespace = "coder"
    labels = {
      "app.kubernetes.io/name"     = "coder-workspace"
      "app.kubernetes.io/instance" = "coder-workspace-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}"
      "app.kubernetes.io/part-of"  = "coder"
      // Coder specific labels.
      "com.coder.resource"       = "true"
      "com.coder.workspace.id"   = data.coder_workspace.me.id
      "com.coder.workspace.name" = data.coder_workspace.me.name
      "com.coder.user.id"        = data.coder_workspace.me.owner_id
      "com.coder.user.username"  = data.coder_workspace.me.owner
    }
    annotations = {
      "com.coder.user.email" = data.coder_workspace.me.owner_email
    }
  }
  spec {
    security_context {
      se_linux_options {
        
      }
      
    }
    container {
      name              = "dev"
      # image             = "image-registry.openshift-image-registry.svc:5000/coder/enterprise-base"
      image             = "image-registry.openshift-image-registry.svc:5000/coder/rootless-podman:latest"
      image_pull_policy = "Always"
      command           = ["sh", "-c", coder_agent.dev.init_script]
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.dev.token
      }
      volume_mount {
        mount_path = "/home/coder"
        name       = "home"
        read_only  = false
      }
      resources {
        limits = {
          # Acquire a FUSE device, powered by smarter-device-manager
          "github.com/fuse" : 1
        }
      }
    }
    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
        read_only  = false
      }
    }

    affinity {
      pod_anti_affinity {
        // This affinity attempts to spread out all workspace pods evenly across
        // nodes.
        preferred_during_scheduling_ignored_during_execution {
          weight = 1
          pod_affinity_term {
            topology_key = "kubernetes.io/hostname"
            label_selector {
              match_expressions {
                key      = "app.kubernetes.io/name"
                operator = "In"
                values   = ["coder-workspace"]
              }
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-pvc-${data.coder_workspace.me.id}"
    namespace = "coder"
  }
  wait_until_bound = false
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }
}
