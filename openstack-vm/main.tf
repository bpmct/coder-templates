terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.51.1"
    }
    coder = {
      source  = "coder/coder"
      version = "~> 0.11.1"
    }
  }
}

variable "password" {
  sensitive = true
}

provider "coder" {
}

provider "openstack" {
  # Configuration is set via environment variables
}

locals {
  use_cases = {
    web_development: {
      name: "Web development"
      icon: "/emojis/1f30f.png"
      flavor_name: "gen.micro"
      image_id: "65d8de6d-92b2-441e-8c95-b70594d529fb" # Ubuntu 22.04
    }
    sre_ops: {
      name: "SRE / Ops"
      icon: "/emojis/1f50c.png"
      flavor_name: "gen.large"
      image_id: "2297d170-0a1d-442c-a9df-2ff6f73062b8" # Debian 11
    }
  }
}

data "coder_parameter" "use_case" {
  name         = "use_case"
  display_name = "Use case"
  description  = "What do you plan on using this development environment for?"
  default      = "web_development"
  mutable      = false

  dynamic "option" {
    for_each = local.use_cases
    content {
      name  = option.value.name
      value = option.key
      icon = option.value.icon 
    }
  }
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
    #install code-server
    curl -fsSL https://code-server.dev/install.sh | sh
    code-server --auth none --port 13337 >/dev/null 2>&1 &
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
  count        = data.coder_workspace.me.start_count
  agent_id     = coder_agent.main[0].id
  display_name = "VS Code"
  slug         = "code-server"
  url          = "http://localhost:13337/?folder=/home/ubuntu"
  icon         = "/icon/code.svg"
  share        = "owner"
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

sudo CODER_AGENT_TOKEN=$(curl -s http://169.254.169.254/openstack/latest/meta_data.json | jq -r .meta.coder_agent_token) -u ubuntu sh -c '${try(coder_agent.main[0].init_script, "")}'
--//--
EOT

}


resource "openstack_compute_instance_v2" "dev" {
  name        = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
  image_id    = local.use_cases[data.coder_parameter.use_case.value].image_id
  flavor_name = local.use_cases[data.coder_parameter.use_case.value].flavor_name
  key_pair    = "bens-macbook"

  block_device {
    uuid                  = local.use_cases[data.coder_parameter.use_case.value].image_id
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
