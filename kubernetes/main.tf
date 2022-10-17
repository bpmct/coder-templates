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

variable "workspaces_namespace" {
  type        = string
  sensitive   = true
  description = "The namespace to create workspaces in (must exist prior to creating workspaces)"
  default     = "coder-workspaces"
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

data "coder_workspace" "me" {}

resource "coder_agent" "go" {
  os             = "linux"
  arch           = "amd64"
  dir            = "/home/vscode"
  startup_script = <<EOF
    #!/bin/sh
    curl -fsSL https://code-server.dev/install.sh | sh
    code-server --auth none --port 13337 & 

    sudo apt-get update && sudo apt-get install -y python3 python3-pip

    # install projector
    PROJECTOR_BINARY=/home/vscode/.local/bin/projector
    if [ -f $PROJECTOR_BINARY ]; then
        echo 'projector has already been installed - check for update'
        /home/vscode/.local/bin/projector self-update 2>&1 | tee projector.log
    else
        echo 'installing projector'
        pip3 install projector-installer --user 2>&1 | tee projector.log
    fi

    echo 'access projector license terms'
    /home/vscode/.local/bin/projector --accept-license 2>&1 | tee -a projector.log

    PROJECTOR_CONFIG_PATH=/home/vscode/.projector/configs/goland

    if [ -d "$PROJECTOR_CONFIG_PATH" ]; then
        echo 'projector has already been configured and the JetBrains IDE downloaded - skip step' 2>&1 | tee -a projector.log
    else
        echo 'autoinstalling IDE and creating projector config folder'
        /home/vscode/.local/bin/projector ide autoinstall --config-name "goland" --ide-name "GoLand 2021.3" --hostname=localhost --port 8997 --use-separate-config --password coder 2>&1 | tee -a projector.log

        # delete the configuration's run.sh input parameters that check password tokens since tokens do not work with coder_app yet passed in the querystring
        grep -iv "HANDSHAKE_TOKEN" $PROJECTOR_CONFIG_PATH/run.sh > temp && mv temp $PROJECTOR_CONFIG_PATH/run.sh 2>&1 | tee -a projector.log
        chmod +x $PROJECTOR_CONFIG_PATH/run.sh 2>&1 | tee -a projector.log

        echo "creation of goland configuration complete" 2>&1 | tee -a projector.log
    fi

    # start JetBrains projector-based IDE
    /home/vscode/.local/bin/projector run goland &
  EOF
}

resource "coder_agent" "java" {
  os             = "linux"
  arch           = "amd64"
  dir            = "/home/vscode"
  startup_script = <<EOF
    #!/bin/sh
    curl -fsSL https://code-server.dev/install.sh | sh
    code-server --auth none --port 13337 &

    sudo apt-get update && sudo apt-get install -y python3 python3-pip

    # install projector
    PROJECTOR_BINARY=/home/vscode/.local/bin/projector
    if [ -f $PROJECTOR_BINARY ]; then
        echo 'projector has already been installed - check for update'
        /home/vscode/.local/bin/projector self-update 2>&1 | tee projector.log
    else
        echo 'installing projector'
        pip3 install projector-installer --user 2>&1 | tee projector.log
    fi

    echo 'access projector license terms'
    /home/vscode/.local/bin/projector --accept-license 2>&1 | tee -a projector.log

    PROJECTOR_CONFIG_PATH=/home/vscode/.projector/configs/intellij

    if [ -d "$PROJECTOR_CONFIG_PATH" ]; then
        echo 'projector has already been configured and the JetBrains IDE downloaded - skip step' 2>&1 | tee -a projector.log
    else
        echo 'autoinstalling IDE and creating projector config folder'
        /home/vscode/.local/bin/projector ide autoinstall --config-name "intellij" --ide-name "IntelliJ IDEA Community Edition 2021.3" --hostname=localhost --port 8997 --use-separate-config --password coder 2>&1 | tee -a projector.log

        # delete the configuration's run.sh input parameters that check password tokens since tokens do not work with coder_app yet passed in the querystring
        grep -iv "HANDSHAKE_TOKEN" $PROJECTOR_CONFIG_PATH/run.sh > temp && mv temp $PROJECTOR_CONFIG_PATH/run.sh 2>&1 | tee -a projector.log
        chmod +x $PROJECTOR_CONFIG_PATH/run.sh 2>&1 | tee -a projector.log

        echo "creation of intellij configuration complete" 2>&1 | tee -a projector.log
    fi

    # start JetBrains projector-based IDE
    /home/vscode/.local/bin/projector run intellij &

EOF
}

resource "coder_agent" "ubuntu" {
  os             = "linux"
  arch           = "amd64"
  dir            = "/home/vscode"
  startup_script = <<EOF
    #!/bin/sh
    curl -fsSL https://code-server.dev/install.sh | sh
    code-server --auth none --port 13337
  EOF
}

resource "coder_agent" "ubuntu-ephemeral" {
  os             = "linux"
  arch           = "amd64"
  dir            = "/home/vscode"
  startup_script = <<EOF
    #!/bin/sh
    curl -fsSL https://code-server.dev/install.sh | sh
    code-server --auth none --port 13337
  EOF
}

# code-server
resource "coder_app" "code-server1" {
  agent_id      = coder_agent.go.id
  name          = "code-server"
  icon          = "/icon/code.svg"
  url           = "http://localhost:13337"
  relative_path = true
}

# goland
resource "coder_app" "goland" {
  agent_id      = coder_agent.go.id
  name          = "GoLand"
  icon          = "/icon/goland.svg"
  url           = "http://localhost:8997"
  relative_path = true
}

# intellij
resource "coder_app" "intellij" {
  agent_id      = coder_agent.java.id
  name          = "IntelliJ IDEA"
  icon          = "/icon/goland.svg"
  url           = "http://localhost:8997"
  relative_path = true
}

# code-server
resource "coder_app" "code-server2" {
  agent_id      = coder_agent.ubuntu.id
  name          = "VS Code"
  icon          = "/icon/code.svg"
  url           = "http://localhost:13337"
  relative_path = true
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
    container {
      name    = "ubuntu-ephemeral"
      image   = "mcr.microsoft.com/vscode/devcontainers/base:ubuntu"
      command = ["sh", "-c", coder_agent.ubuntu-ephemeral.init_script]
      security_context {
        run_as_user = "1000"
      }
      env {
        name  = "CODER_AGENT_TOKEN"
        value = coder_agent.ubuntu-ephemeral.token
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
