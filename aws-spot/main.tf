terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.4.2"
    }
  }
}

variable "region" {
  description = "What region should your workspace live in?"
  default     = "us-west-2"
  validation {
    condition = contains([
      "eu-central-1",
      "us-west-2"
    ], var.region)
    error_message = "Invalid region!"
  }
}

locals {
  aws_instances = {
    "2 Cores, 8 GB RAM"  = "t3.large"
    "4 Cores, 16 GB RAM" = "t3.xlarge"
    "8 Cores, 32 GB RAM" = "t3.2xlarge"
  }
}

variable "type" {
  description = "Instance size"
  default     = "2 Cores, 8 GB RAM"
  validation {
    condition = contains(
      [
        "2 Cores, 8 GB RAM",
        "4 Cores, 16 GB RAM",
        "8 Cores, 32 GB RAM"
    ], var.type)
    error_message = "Invalid type!"
  }
}

# code-server
resource "coder_app" "code-server" {
  agent_id      = coder_agent.dev.id
  name          = "code-server"
  icon          = "https://cdn.icon-icons.com/icons2/2107/PNG/512/file_type_vscode_icon_130084.png"
  url           = "http://localhost:13337"
  relative_path = true
}

provider "aws" {
  region = var.region
}

data "coder_workspace" "me" {
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

resource "coder_agent" "dev" {
  arch           = "amd64"
  auth           = "token"
  dir            = "/home/${lower(data.coder_workspace.me.owner)}"
  os             = "linux"
  startup_script = <<EOT
#!/bin/sh
export HOME=/home/${lower(data.coder_workspace.me.owner)}
curl -fsSL https://code-server.dev/install.sh | sh
code-server --auth none --port 13337
  EOT
}

locals {

  # User data is used to stop/start AWS instances. See:
  # https://github.com/hashicorp/terraform-provider-aws/issues/22

  user_data_start = <<EOT
Content-Type: multipart/mixed; boundary="//"
MIME-Version: 1.0

--//
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="cloud-config.txt"

#cloud-config
hostname: ${lower(data.coder_workspace.me.name)}
users:
- name: ${lower(data.coder_workspace.me.owner)}
  sudo: ALL=(ALL) NOPASSWD:ALL
  shell: /bin/bash
cloud_final_modules:
- [scripts-user, always]

--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="userdata.txt"

#!/bin/bash
export CODER_AGENT_TOKEN=${coder_agent.dev.token}
sudo --preserve-env=CODER_AGENT_TOKEN -u ${lower(data.coder_workspace.me.owner)} /bin/bash -c '${coder_agent.dev.init_script}'
--//--
EOT

  user_data_end = <<EOT
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

--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="userdata.txt"

#!/bin/bash
sudo shutdown -h now
--//--
EOT
}

resource "aws_spot_instance_request" "dev" {
  ami                            = data.aws_ami.ubuntu.id
  availability_zone              = "${var.region}a"
  instance_type                  = lookup(local.aws_instances, var.type)
  instance_interruption_behavior = "stop"

  wait_for_fulfillment = true

  user_data = data.coder_workspace.me.transition == "start" ? local.user_data_start : local.user_data_end
  tags = {
    Name = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
    # Required if you are using our example policy, see template README
    Coder_Provisioned = "true"
  }
}
