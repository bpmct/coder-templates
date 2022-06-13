terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.4.2"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.10"
    }
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



data "coder_workspace" "me" {
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

# https://yetiops.net/posts/proxmox-terraform-cloudinit-saltstack-prometheus/

variable "pm_api_url" {
  sensitive = true
}

variable "pm_api_token_id" {
  sensitive = true
}

variable "pm_api_token_secret" {
  sensitive = true
}

variable "pm_tls_insecure" {
  sensitive = true
  default   = true
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

resource "null_resource" "cloud_init_config_files" {
  count = 1
  connection {
    type        = "ssh"
    user        = "root"
    host        = "proxmox"
    private_key = file("/root/.ssh/id_rsa")
  }

  provisioner "file" {
    source      = local_file.cloud_init_user_data_file[count.index].filename
    destination = "/var/lib/vz/snippets/user_data_vm-${count.index}.yml"
  }
}

# /* Configure Cloud-Init User-Data with custom config file */
# resource "proxmox_vm_qemu" "cloudinit-test" {
#   count = 1
#   depends_on = [
#     null_resource.cloud_init_config_files,
#   ]

#   name        = "tftest1"
#   desc        = "tf description"
#   target_node = "proxmox"

#   clone = "ubuntu2004-cloud-output"

#   storage = "local-lvm"
#   cores   = 2
#   sockets = 2
#   memory  = 2048
#   disk_gb = 4
#   nic     = "virtio"
#   bridge  = "vmbr0"

#   ssh_user        = "root"
#   ssh_private_key = <<EOF
# -----BEGIN RSA PRIVATE KEY-----
# private ssh key root
# -----END RSA PRIVATE KEY-----
# EOF

#   os_type   = "cloud-init"
#   ipconfig0 = "ip=10.0.2.99/16,gw=10.0.2.2"

#   /*
#     sshkeys and other User-Data parameters are specified with a custom config file.
#     In this example each VM has its own config file, previously generated and uploaded to
#     the snippets folder in the local storage in the Proxmox VE server.
#   */
#   cicustom = "user=local:snippets/user_data_vm-${count.index}.yml"
#   /* Create the Cloud-Init drive on the "local-lvm" storage */
#   cloudinit_cdrom_storage = "local-lvm"

#   # provisioner "remote-exec" {
#   #   inline = [
#   #     "ip a"
#   #   ]
#   # }
# }

/* Null resource that generates a cloud-config file per vm */
data "template_file" "user_data" {
  count    = 1
  template = file("${path.module}/files/user_data.cfg")
  vars = {
    pubkey   = file(pathexpand("~/.ssh/id_rsa.pub"))
    hostname = "vm-${count.index}"
    fqdn     = "vm-${count.index}.lan"
  }
}

resource "local_file" "cloud_init_user_data_file" {
  count    = 1
  content  = data.template_file.user_data[count.index].rendered
  filename = "${path.module}/files/user_data_${count.index}.cfg"
}


# resource "aws_spot_instance_request" "dev" {
#   ami                            = data.aws_ami.ubuntu.id
#   availability_zone              = "${var.region}a"
#   instance_type                  = var.type
#   instance_interruption_behavior = "stop"

#   wait_for_fulfillment = true

#   user_data = data.coder_workspace.me.transition == "start" ? local.user_data_start : local.user_data_end
#   tags = {
#     Name = "coder-${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}"
#     # Required if you are using our example policy, see template README
#     Coder_Provisioned = "true"
#   }
# }
