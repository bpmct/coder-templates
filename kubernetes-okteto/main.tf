terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.6.14"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.18.1"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

data "coder_workspace" "me" {}

# Used for all resources created by this template
locals {
  name = "coder-ws-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}"
  labels = {
    "app.kubernetes.io/managed-by" = "coder"
  }
}

resource "kubernetes_namespace" "workspace" {
  metadata {
    name   = local.name
    labels = local.labels
  }
}

resource "coder_metadata" "namespace-info" {
  resource_id = kubernetes_namespace.workspace.id
  icon        = "https://svgur.com/i/qsx.svg"
  item {
    key   = "name in cluster"
    value = local.name
  }
}

# ServiceAccount for the workspace
resource "kubernetes_service_account" "workspace_service_account" {
  metadata {
    name      = local.name
    namespace = kubernetes_namespace.workspace.metadata[0].name
    labels    = local.labels
  }
}

# Gives the ServiceAccount admin access to the
# namespace created for this workspace
resource "kubernetes_role_binding" "set_workspace_permissions" {
  metadata {
    name      = local.name
    namespace = kubernetes_namespace.workspace.metadata[0].name
    labels    = local.labels
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.workspace_service_account.metadata[0].name
    namespace = kubernetes_namespace.workspace.metadata[0].name
  }
}

# The Coder agent allows the workspace owner
# to connect to the pod from a web or local IDE
resource "coder_agent" "primary" {
  os   = "linux"
  arch = "amd64"

  login_before_ready     = false
  startup_script_timeout = 180
  startup_script         = <<-EOT
    set -e

    # install and start code-server
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server --version 4.8.3
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &
  EOT
}

# Adds the "VS Code Web" icon to the dashboard
# and proxies code-server running on the workspace
resource "coder_app" "code-server" {
  agent_id     = coder_agent.primary.id
  display_name = "VS Code Web"
  slug         = "code-server"
  url          = "http://localhost:13337/"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}

# Creates a pod on the workspace namepace, allowing
# the developer to connect.
resource "kubernetes_pod" "primary" {

  # Pod is ephemeral. Re-created when a workspace starts/stops.
  count = data.coder_workspace.me.start_count

  metadata {
    name      = "primary"
    namespace = kubernetes_namespace.workspace.metadata[0].name
    labels    = local.labels
  }
  spec {

    # Only some nodes in the cluster support envbox
    node_selector = {
      sreya-test = true
    }

    # toleration {
    #   key  = "com.coder.workspace.preemptible"
    #   vaue = "true"
    # }

    service_account_name = kubernetes_service_account.workspace_service_account.metadata[0].name
    container {
      name              = "dev"
      image             = "gcr.io/coder-dogfood/sreya/envbox:benp"
      image_pull_policy = "Always"
      command           = ["/envbox", "docker"]

      security_context {
        privileged = true
      }

      # resources {
      #   requests = {
      #     "cpu" : "0.5"
      #     "memory" : "1G"
      #   }

      #   limits = {
      #     "cpu" : "2"
      #     "memory" : "4G"
      #   }
      # }

      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.primary.token
      }

      env {
        name  = "CODER_AGENT_URL"
        value = data.coder_workspace.me.access_url
      }

      env {
        name  = "CODER_INNER_IMAGE"
        value = "bencdr/devops-tools:latest"
      }

      env {
        name  = "CODER_INNER_USERNAME"
        value = "coder"
      }

      env {
        name  = "CODER_BOOTSTRAP_SCRIPT"
        value = coder_agent.primary.init_script
      }

      env {
        name  = "CODER_MOUNTS"
        value = "/home/coder:/home/coder,/var/run/secrets/kubernetes.io/serviceaccount:/var/run/secrets/kubernetes.io/serviceaccount:ro"
      }

      env {
        name  = "CODER_ADD_FUSE"
        value = "true"
      }

      env {
        name  = "CODER_ADD_TUN"
        value = "true"
      }

      env {
        name = "CODER_CPUS"
        value_from {
          resource_field_ref {
            resource = "limits.cpu"
          }
        }
      }

      env {
        name = "CODER_MEMORY"
        value_from {
          resource_field_ref {
            resource = "limits.memory"
          }
        }
      }

      volume_mount {
        mount_path = "/home/coder"
        name       = "home"
        read_only  = false
        sub_path   = "home"
      }

      volume_mount {
        mount_path = "/var/lib/coder/docker"
        name       = "home"
        sub_path   = "cache/docker"
      }

      volume_mount {
        mount_path = "/var/lib/coder/containers"
        name       = "home"
        sub_path   = "cache/containers"
      }

      volume_mount {
        mount_path = "/var/lib/sysbox"
        name       = "sysbox"
      }

      volume_mount {
        mount_path = "/var/lib/containers"
        name       = "home"
        sub_path   = "envbox/containers"
      }

      volume_mount {
        mount_path = "/var/lib/docker"
        name       = "home"
        sub_path   = "envbox/docker"
      }

      volume_mount {
        mount_path = "/usr/src"
        name       = "usr-src"
      }

      volume_mount {
        mount_path = "/lib/modules"
        name       = "lib-modules"
      }
    }

    volume {
      name = "home"
      persistent_volume_claim {
        claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
        read_only  = false
      }
    }

    volume {
      name = "sysbox"
      empty_dir {}
    }

    volume {
      name = "usr-src"
      host_path {
        path = "/usr/src"
        type = ""
      }
    }

    volume {
      name = "lib-modules"
      host_path {
        path = "/lib/modules"
        type = ""
      }
    }
  }
}

# Creates a persistent volume for developers
# to store their repos/files
resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "primary-disk"
    namespace = kubernetes_namespace.workspace.metadata[0].name
    labels    = local.labels
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

# Metadata for resources

resource "coder_metadata" "primary_metadata" {
  count       = data.coder_workspace.me.start_count
  resource_id = kubernetes_pod.primary[0].id
  icon        = "https://svgur.com/i/qrK.svg"
}

resource "coder_metadata" "pvc_metadata" {
  resource_id = kubernetes_persistent_volume_claim.home.id
  icon        = "https://svgur.com/i/qt5.svg"
  item {
    key   = "mounted dir"
    value = "/home/coder"
  }
}

resource "coder_metadata" "service_account_metadata" {
  resource_id = kubernetes_service_account.workspace_service_account.id
  icon        = "https://svgur.com/i/qrv.svg"
  hide        = true
}


resource "coder_metadata" "role_binding_metadata" {
  resource_id = kubernetes_role_binding.set_workspace_permissions.id
  icon        = "https://svgur.com/i/qs7.svg"
  hide        = true
}
