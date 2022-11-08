data "coder_workspace" "me" {}

resource "coder_agent" "main" {
  os             = "linux"
  arch           = "amd64"
  dir            = "/home/coder/projects"
  startup_script = <<-EOT
    #!/bin/bash
    # install and start code-server
    curl -fsSL https://code-server.dev/install.sh | bash | tee code-server-install.log
    code-server --auth none --port 13337 | tee code-server-install.log &
  EOT
}

resource "coder_app" "code-server" {
  agent_id = coder_agent.main.id
  name     = "code-server"
  icon     = "/icon/code.svg"
  url      = "http://localhost:13337?folder=/home/coder"
}

resource "coder_app" "vim" {
  agent_id = coder_agent.main.id
  name     = "Vim"
  # TODO: revert to local icon when it's added
  icon    = "https://upload.wikimedia.org/wikipedia/commons/9/9f/Vimlogo.svg"
  command = "vim"
}

resource "coder_metadata" "pod_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = kubernetes_deployment.main.id
  item {
    key   = "CPU"
    value = kubernetes_deployment.main.spec[0].template[0].spec[0].container[0].resources[0].limits.cpu
  }
  item {
    key   = "Memory"
    value = kubernetes_deployment.main.spec[0].template[0].spec[0].container[0].resources[0].limits.memory
  }
  item {
    key   = "Image"
    value = kubernetes_deployment.main.spec[0].template[0].spec[0].container[0].image
  }
}

resource "coder_metadata" "home_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = kubernetes_persistent_volume_claim.home.id
  item {
    key   = "Size"
    value = kubernetes_persistent_volume_claim.home.spec[0].resources[0].requests.storage
  }
}

resource "coder_metadata" "localstack_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = kubernetes_persistent_volume_claim.localstack.id
  item {
    key   = "Size"
    value = kubernetes_persistent_volume_claim.localstack.spec[0].resources[0].requests.storage
  }
}

resource "coder_metadata" "postgres_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = kubernetes_persistent_volume_claim.postgres.id
  item {
    key   = "Size"
    value = kubernetes_persistent_volume_claim.postgres.spec[0].resources[0].requests.storage
  }
}
