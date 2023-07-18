terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 0.8.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.3"
    }
  }
}

# Last updated 2023-03-14
# aws ec2 describe-regions | jq -r '[.Regions[].RegionName] | sort'
data "coder_parameter" "region" {
  name        = "Region"
  description = "The region to deploy the workspace in."
  default     = "us-east-2"
  icon        = "/emojis/1f310.png"
  mutable     = false
  option {
    name  = "US East"
    value = "us-east-2"
    icon  = "/emojis/1f1fa-1f1f8.png"
  }
}

data "coder_parameter" "instance_type" {
  name        = "Instance Types"
  description = "What instance type should your workspace use?"
  default     = "mac1.metal"
  icon        = "/emojis/1f5a5.png"
  mutable     = false
  option {
    name  = "12 vCPU, 32 GiB RAM"
    value = "mac1.metal"
  }
  option {
    name  = "2 vCPU, 8 GiB RAM"
    value = "t3.large"
  }
}

provider "aws" {
  region = data.coder_parameter.region.value
}

data "coder_workspace" "me" {
}

resource "coder_agent" "main" {
  arch                   = "amd64"
  auth                   = "aws-instance-identity"
  count                  = data.coder_workspace.me.start_count
  os                     = "darwin"
  startup_script_timeout = 480
  startup_script         = <<-EOT
    #!/bin/zsh
    set -e

    # install and start code-server
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server --version 4.8.3
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &
  EOT
}

resource "coder_app" "code-server" {
  count        = data.coder_workspace.me.start_count
  agent_id     = coder_agent.main[0].id
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
  user_data = <<EOT
#!/bin/zsh

# Write the init script to a file
echo '${try(coder_agent.main[0].init_script, "")}' >/tmp/init_script.sh
chmod +x /tmp/init_script.sh

# Create a LaunchDaemon plist file
launch_daemon_file=/Library/LaunchDaemons/com.coder.agent.plist
if [[ ! -e "$launch_daemon_file" ]]; then
    /bin/cat <<-EOM >/tmp/com.coder.agent.plist
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>com.coder.agent</string>
        <key>ProgramArguments</key>
        <array>
            <string>/bin/zsh</string>
            <string>-c</string>
            <string>/tmp/init_script.sh</string>
        </array>
        <key>UserName</key>
        <string>ec2-user</string>
        <key>KeepAlive</key>
        <true/>
    </dict>
    </plist>
EOM

    # Move the plist file to the correct location and load it
    sudo mv /tmp/com.coder.agent.plist "$launch_daemon_file"
    sudo chown root:wheel "$launch_daemon_file"
    sudo chmod 644 "$launch_daemon_file"
    sudo launchctl load -w "$launch_daemon_file"
fi

EOT
}


resource "aws_ec2_host" "dedicated_mac" {
  instance_type     = "mac1.metal"
  availability_zone = "us-east-2b"
}

resource "aws_instance" "workspace" {
  ami                         = "ami-02d595c83c5e8504a"
  availability_zone           = "${data.coder_parameter.region.value}b"
  instance_type               = data.coder_parameter.instance_type.value
  user_data_replace_on_change = false
  tenancy                     = "host"
  host_id                     = aws_ec2_host.dedicated_mac.id
  root_block_device {
    volume_size           = "100"
    volume_type           = "gp2"
    encrypted             = false
    delete_on_termination = true
  }

  user_data = local.user_data
  tags = {
    Name = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
    # Required if you are using our example policy, see template README
    Coder_Provisioned = "true"
    Environment       = "Production"
    Usecase           = "General"
    UserName          = "${data.coder_workspace.me.owner}"
  }

}

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = aws_instance.workspace.id
  item {
    key   = "Public IP Address"
    value = aws_instance.workspace.public_ip
  }
  item {
    key   = "Region"
    value = data.coder_parameter.region.value
  }
  item {
    key   = "Instance Type"
    value = aws_instance.workspace.instance_type
  }
  item {
    key   = "Disk"
    value = "${aws_instance.workspace.root_block_device[0].volume_size} GiB"
  }
}

resource "null_resource" "start" {

  depends_on = [aws_instance.workspace]

  triggers = {
    start_count = data.coder_workspace.me.start_count
  }

  provisioner "local-exec" {

    command = <<EOT
      if [ "${data.coder_workspace.me.start_count}" -eq 1 ]; then
        aws ec2 start-instances \
         --instance-ids ${aws_instance.workspace.id} \
         --region ${data.coder_parameter.region.value}
      elif [ "${data.coder_workspace.me.start_count}" -eq 0 ]; then
        aws ec2 stop-instances \
          --instance-ids ${aws_instance.workspace.id} \
          --region ${data.coder_parameter.region.value}
      fi
    EOT
  }
}
