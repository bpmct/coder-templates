terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.51.1"
    }
    coder = {
      source  = "coder/coder"
      version = "~> 0.7.0"
    }
  }
}

variable "password" {
  sensitive = true
}

provider "coder" {
  feature_use_managed_variables = "true"
}

provider "openstack" {
  # Configuration is set via environment variables
}


data "coder_workspace" "me" {
}

resource "coder_agent" "main" {
  count = data.coder_workspace.me.start_count
  arch  = "amd64"
  os    = "linux"
  dir   = "/home/ubuntu"

  startup_script = <<EOT
    #!/bin/bash
    # install code-server
    curl -fsSL https://code-server.dev/install.sh | sh
    code-server --auth none --port 13337 &
    # use coder CLI to clone and install dotfiles
  EOT 


  metadata {
    display_name = "CPU Usage"
    key          = "cpu"
    # calculates CPU usage by summing the "us", "sy" and "id" columns of
    # vmstat.
    script = <<EOT
top -bn1 | awk 'FNR==3 {printf "%2.0f%%", $2+$3+$4}'
EOT

    interval = 1
    timeout  = 1
  }


  metadata {
    display_name = "Disk Usage"
    key          = "disk"
    script       = "df -h | awk '$6 ~ /^\\/$/ { print $5 }'"
    interval     = 1
    timeout      = 1
  }

  metadata {
    display_name = "Memory Usage"
    key          = "mem"
    script       = <<EOT
free | awk '/^Mem/ { printf("%.0f%%", $4/$2 * 100.0) }'
EOT
    interval     = 1
    timeout      = 1
  }

  metadata {
    display_name = "Load Average"
    key          = "load"
    script       = <<EOT
awk '{print $1,$2,$3}' /proc/loadavg
EOT
    interval     = 1
    timeout      = 1
  }

}

resource "coder_app" "code-server" {
  count    = data.coder_workspace.me.start_count
  agent_id = coder_agent.main[0].id
  name     = "VS Code"
  slug     = "code-server"
  url      = "http://localhost:13337/?folder=/home/${lower(data.coder_workspace.me.owner)}"
  icon     = "/icon/code.svg"
}


locals {

  # User data is used to stop/start AWS instances. See:
  # https://github.com/hashicorp/terraform-provider-aws/issues/22

  user_data = <<EOT
Content-Type: multipart/mixed; boundary="//"
MIME-Version: 1.0
--//
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="cloud-config.txt"
#cloud-config
cloud_final_modules:
- [scripts-user, always]
hostname: ${lower(data.coder_workspace.me.name)}
--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="userdata.txt"
#!/bin/bash

set -eux pipefail

apt-get update
apt-get install -y jq

# Grabs token via the internal metadata server. This IP address is the same for all instances, no need to change it
# https://docs.openstack.org/nova/rocky/user/metadata-service.html
sudo CODER_AGENT_TOKEN=$(curl -s http://169.254.169.254/openstack/latest/meta_data.json | jq -r .meta.coder_agent_token) -u ubuntu sh -c '${try(coder_agent.main[0].init_script, "")}'
--//--
EOT

}


resource "openstack_compute_instance_v2" "dev" {
  name        = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
  image_id    = "bdf0bfbe-8ee3-40c1-9695-2f97ba31441f"
  flavor_name = "gen.micro"
  key_pair    = "bens-macbook"

  block_device {
    uuid                  = "bdf0bfbe-8ee3-40c1-9695-2f97ba31441f"
    source_type           = "image"
    volume_size           = 20
    destination_type      = "local"
    boot_index            = 0
    delete_on_termination = true
  }

  metadata = {
    coder_agent_token = try(coder_agent.main[0].token, "")
  }

  security_groups = ["default"]
  power_state     = data.coder_workspace.me.transition == "start" ? "active" : "shutoff"
  user_data       = local.user_data

  tags = ["Name=coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}", "Coder_Provisioned=true"]

  lifecycle {
    ignore_changes = [user_data]
  }

  network {
    name = "External"
  }
}
