terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "coder" {
}

variable "auth_token" {
  description = "access token"
}
variable "project_id" {
  description = "Which Google Compute Project should your workspace live in?"
  default     = "adls-e03zggt78292mwvbyqb2kb8q5"
}
variable "service_account" {
  description = "Which Google Compute Project should your workspace live in?"
  default     = "970973019406-compute@developer.gserviceaccount.com"
}
variable "tenant" {
  description = "ADLS convention of naming tenants"
  default     = "0007-dev"
}
data "coder_parameter" "zone" {
  name         = "zone"
  display_name = "Zone"
  description  = "Which zone should your workspace live in?"
  type         = "string"
  icon         = "/emojis/1f30e.png"
  default      = "europe-west1-b"
  mutable      = false
  option {
    name  = "North America (West)"
    value = "us-west2-c"
    icon  = "/emojis/1f1fa-1f1f8.png"
  }
  option {
    name  = "Europe (West)"
    value = "europe-west1-b"
    icon  = "/emojis/1f1ea-1f1fa.png"
  }
}


data "coder_parameter" "token" {
  name         = "token"
  display_name = "GCPToken"
  description  = "Please provide an uptodate OAuth Token"
  type         = "string"
  default      = "ya29.a0AfB_byD7N3OePHk9ldYO4oE6oUyV9Qsn9Mhpnpq_loJrpLq3i68GWbaV4nTDXj0GgwxS3w9XyPT9Tp3XtNeJZUskBeBHfbR2dRq1LYThHrq_Vh7o_7wBqdRlDHQF5aoQQOFc37HZJ1APVLC7VqmmMBtdjeyGMjUherIL87CXOa_ZaCgYKASYSARASFQHGX2MijHuMVRHLBvcnve8GC8UMRw0179"
  mutable      = true

}

provider "google" {
  zone    = data.coder_parameter.zone.value
  project = var.project_id
  access_token = data.coder_parameter.token.value
}


data "coder_workspace" "me" {
}

resource "google_compute_disk" "root" {
  name  = "coder-${data.coder_workspace.me.id}-root"
  type  = "pd-standard"
  zone  = data.coder_parameter.zone.value
  image = "debian-cloud/debian-12"
  lifecycle {
    ignore_changes = [name, image]
  }
}


resource "coder_agent" "main" {
  auth                   = "google-instance-identity"
  #auth                   = "token"
  arch                   = "amd64"
  os                     = "linux"
  startup_script_timeout = 180
  startup_script         = <<-EOT
    set -e

    # install and start code-server
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server --version 4.11.0
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &
  EOT

  metadata {
    key          = "cpu"
    display_name = "CPU Usage"
    interval     = 5
    timeout      = 5
    script       = <<-EOT
      #!/bin/bash
      set -e
      top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4 "%"}'
    EOT
  }
  metadata {
    key          = "memory"
    display_name = "Memory Usage"
    interval     = 5
    timeout      = 5
    script       = <<-EOT
      #!/bin/bash
      set -e
      free -m | awk 'NR==2{printf "%.2f%%\t", $3*100/$2 }'
    EOT
  }
  metadata {
    key          = "disk"
    display_name = "Disk Usage"
    interval     = 600 # every 10 minutes
    timeout      = 30  # df can take a while on large filesystems
    script       = <<-EOT
      #!/bin/bash
      set -e
      df /home/coder | awk '$NF=="/"{printf "%s", $5}'
    EOT
  }
}


# code-server
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  icon         = "/icon/code.svg"
  url          = "http://localhost:13337?folder=/home/coder"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}

resource "google_compute_instance" "dev" {
  name         = "coder-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}-root"
  machine_type = "e2-medium"
  # data.coder_workspace.me.owner == "default"  is a workaround to suppress error in the terraform plan phase while creating a new workspace.
  desired_status = (data.coder_workspace.me.owner == "default" || data.coder_workspace.me.start_count == 1) ? "RUNNING" : "TERMINATED"


  network_interface {
    access_config {
      network_tier = "PREMIUM"
    }

    queue_count = 0
    stack_type  = "IPV4_ONLY"
    subnetwork  = "projects/${var.project_id}/regions/europe-west1/subnetworks/vpc-snet-caas-${var.tenant}"
  }

  scheduling {
    automatic_restart   = false
    on_host_maintenance = "TERMINATE"
    preemptible         = true
    provisioning_model  = "SPOT"
  }

  service_account {
    email  = var.service_account
    scopes = ["cloud-platform"]
  }

  tags = ["https-server"]

  boot_disk {
    auto_delete = true
    source      = google_compute_disk.root.name
  }


  # The startup script runs as root with no $HOME environment set up, so instead of directly
  # running the agent init script, create a user (with a homedir, default shell and sudo
  # permissions) and execute the init script as that user.
  metadata = {
    # The startup script runs as root with no $HOME environment set up, so instead of directly
    # running the agent init script, create a user (with a homedir, default shell and sudo
    # permissions) and execute the init script as that user.
    startup-script = <<-META
    #!/usr/bin/env sh
    set -eux
    # If user does not exist, create it and set up passwordless sudo
    if ! id -u "${local.linux_user}" >/dev/null 2>&1; then
      useradd -m -s /bin/bash "${local.linux_user}"
      echo "${local.linux_user} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/coder-user
    fi

    exec sudo -u "${local.linux_user}" sh -c '${coder_agent.main.init_script}'
        META
  }
    


}

locals {
  # Ensure Coder username is a valid Linux username
  # linux_user = lower(substr(data.coder_workspace.me.owner, 0, 32))
  linux_user = "coder"
}

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = google_compute_instance.dev.id

  item {
    key   = "type"
    value = google_compute_instance.dev.machine_type
  }

  item {
    key   = "zone"
    value = data.coder_parameter.zone.value
  }
}

resource "coder_metadata" "home_info" {
  resource_id = google_compute_disk.root.id

  item {
    key   = "size"
    value = "${google_compute_disk.root.size} GiB"
  }
}