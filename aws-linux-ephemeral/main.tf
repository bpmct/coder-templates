terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.6.6"
    }
  }
}

# Last updated 2022-05-31
# aws ec2 describe-regions | jq -r '[.Regions[].RegionName] | sort'
variable "region" {
  description = "What region should your workspace live in?"
  default     = "us-east-1"
  validation {
    condition = contains([
      "ap-northeast-1",
      "ap-northeast-2",
      "ap-northeast-3",
      "ap-south-1",
      "ap-southeast-1",
      "ap-southeast-2",
      "ca-central-1",
      "eu-central-1",
      "eu-north-1",
      "eu-west-1",
      "eu-west-2",
      "eu-west-3",
      "sa-east-1",
      "us-east-1",
      "us-east-2",
      "us-west-1",
      "us-west-2"
    ], var.region)
    error_message = "Invalid region!"
  }
}

variable "instance_type" {
  description = "What instance type should your workspace use?"
  default     = "t3.micro"
  validation {
    condition = contains([
      "t3.micro",
      "t3.small",
      "t3.medium",
      "t3.large",
      "t3.xlarge",
      "t3.2xlarge",
    ], var.instance_type)
    error_message = "Invalid instance type!"
  }
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

resource "coder_agent" "main" {
  arch           = "amd64"
  auth           = "aws-instance-identity"
  os             = "linux"
  startup_script = <<EOT
    #!/bin/bash

    # install and start code-server
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --version 4.8.3 | tee code-server-install.log
    code-server --auth none --port 13337 | tee code-server-install.log &

    # Run personalize script, if possibleß
    if [ -x ~/personalize ]; then
      ~/personalize | tee -a ~/.personalize.log
    elif [ -f ~/personalize ]; then
      echo "~/personalize is not executable, skipping..." | tee -a ~/.personalize.log
    fi
  EOT
}

resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337/?folder=/home/coder"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}

locals {

  linux_user = "coder" # Ensure this user/group does not exist in your AMI
  user_data  = <<EOT
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
users:
- name: ${local.linux_user}
  sudo: ALL=(ALL) NOPASSWD:ALL
  shell: /bin/bash

--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="userdata.txt"

#!/bin/bash

sudo apt update -y

# Format the drive if there is no filesystem
if [[ $(sudo file -s /dev/nvme1n1) == "/dev/nvme1n1: data" ]]; then
  sudo mkfs -t ext4 /dev/nvme1n1
  sudo cp -rT /home/coder /tmp/${local.linux_user}
  echo "Initialized filesystem on /dev/nvme1n1"
fi

mount /dev/nvme1n1 /home/${local.linux_user}
echo "Mounted home volume"

# Copy the sample home directory, if empty
if [ -d "/home/${local.linux_user}" ]; then
  sudo cp -rT /tmp/${local.linux_user} /home/coder
  echo "Home directory seeded with operating system files"
  chown -R 1000:1000 /home/${local.linux_user}
fi

sudo -u ${local.linux_user} sh -c '${coder_agent.main.init_script}'
--//--
EOT


}

# Ephemeral AWS Instance (deleted on stop)
resource "aws_instance" "dev" {
  count             = data.coder_workspace.me.start_count
  ami               = data.aws_ami.ubuntu.id
  availability_zone = "${var.region}a"
  instance_type     = var.instance_type

  user_data = local.user_data
  tags = {
    Name = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
    # Required if you are using our example policy, see template README
    Coder_Provisioned = "true"
  }
}

# Persistent EBS "home" volume (for /home/coder)
resource "aws_ebs_volume" "home" {
  availability_zone = "${var.region}a"
  size              = 15

  tags = {
    Name = "coder-homedir-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
    # Required if you are using our example policy, see template README
  Coder_Provisioned = "true" }
}

resource "aws_volume_attachment" "ebs_att" {
  count       = data.coder_workspace.me.start_count
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.home.id
  instance_id = aws_instance.dev[0].id
}

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = aws_instance.dev[0].id
  item {
    key   = "region"
    value = var.region
  }
  item {
    key   = "instance type"
    value = aws_instance.dev[0].instance_type
  }
}
