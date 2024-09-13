terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.13.0"
    }
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

variable "proxmox_api_url" {
  description = "Proxmox API URL (example: https://pve.example.com/api2/json)"
  sensitive   = false
}

variable "proxmox_api_user" {
  description = "Proxmox API Username (example: coder@pve)"
  sensitive   = false
}

variable "proxmox_api_password" {
  description = "Proxmox API Password"
  sensitive   = true
}

variable "proxmox_api_insecure" {
  default     = "false"
  description = "Type \"true\" if you have an self-signed TLS certificate"

  validation {
    condition = contains([
      "true",
      "false"
    ], var.proxmox_api_insecure)
    error_message = "Specify true or false."
  }
  sensitive = false
}

variable "proxmox_ssh_host" {
  description = "Proxmox ssh host (example: \"pve.example.com\")"
  default     = "pve.example.com"
  sensitive   = false
}

variable "proxmox_ssh_port" {
  description = "Proxmox ssh port (example: \"22\")"
  default     = "22"
  sensitive   = false
}

variable "proxmox_ssh_user" {
  description = "Proxmox ssh username (example: \"root\")"
  default     = "root"
  sensitive   = false
}

variable "proxmox_ssh_key_path" {
  description = "Proxmox ssh key path (example: \"/home/coder/.ssh/id_rsa\")"
  default     = "/home/coder/.ssh/id_rsa"
  sensitive   = false
}

variable "vm_target_node" {
  description = "Container target PVE node (example: \"pve\")"
  default     = "pve"
  sensitive   = false
}

variable "vm_target_storage" {
  description = "Container target storage (example: \"local-lvm\")"
  default     = "local-lvm"
  sensitive   = false
}

variable "vm_target_bridge" {
  description = "Container bridge interface (example: \"vmbr0\")"
  default     = "vmbr0"
  sensitive   = false
}

resource "tls_private_key" "rsa_4096" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

data "coder_parameter" "a110_cpu_cores_count" {
  name         = "a110_cpu_cores_count"
  display_name = "CPU Cores Count"
  description  = ""
  default      = 4
  type         = "string"
  icon         = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64' fill='rgba(255,255,255,1)'%3E%3Cpath d='M6 18H18V6H6V18ZM14 20H10V22H8V20H5C4.44772 20 4 19.5523 4 19V16H2V14H4V10H2V8H4V5C4 4.44772 4.44772 4 5 4H8V2H10V4H14V2H16V4H19C19.5523 4 20 4.44772 20 5V8H22V10H20V14H22V16H20V19C20 19.5523 19.5523 20 19 20H16V22H14V20ZM8 8H16V16H8V8Z'%3E%3C/path%3E%3C/svg%3E"
  mutable      = false
  
  option {
    name  = "2 vCpus"
    value = 2
  }
  option {
    name  = "4 vCpus"
    value = 4
  }
  option {
    name  = "6 vCpus"
    value = 6
  }
  option {
    name  = "8 vCpus"
    value = 8
  }

}

data "coder_parameter" "a120_memory_size" {
  name         = "a120_memory_size"
  display_name = "Memory Size"
  description  = ""
  default      = 6144
  type         = "string"
  icon         = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' width='64' height='64' fill='rgba(255,255,255,1)'%3E%3Cpath d='M3 7H21V17H19V15H17V17H15V15H13V17H11V15H9V17H7V15H5V17H3V7ZM2 5C1.44772 5 1 5.44772 1 6V18C1 18.5523 1.44772 19 2 19H22C22.5523 19 23 18.5523 23 18V6C23 5.44772 22.5523 5 22 5H2ZM11 9H5V12H11V9ZM13 9H19V12H13V9Z'%3E%3C/path%3E%3C/svg%3E"
  mutable      = false
  # option {
  #   name  = "2 GB"
  #   value = 2048
  # }
  option {
    name  = "4 GB"
    value = 4096
  }
  option {
    name  = "6 GB"
    value = 6144
  }
  option {
    name  = "8 GB"
    value = 8192
  }
  option {
    name  = "16 GB"
    value = 16384
  }
}

data "coder_parameter" "a130_disk_size" {
  name         = "a130_disk_size"
  display_name = "Disk Size"
  description  = ""
  default      = 32
  type         = "string"
  icon         = "/icon/database.svg"
  mutable      = false

  # option {
  #   name  = "16 GB"
  #   value = 16
  # }
  option {
    name  = "24 GB"
    value = 24
  }
  option {
    name  = "32 GB"
    value = 32
  }
  option {
    name  = "64 GB"
    value = 64
  }
  # option {
  #   name  = "128 GB"
  #   value = 128
  # }
}

data "coder_parameter" "a40_should_install_code_server" {
  name         = "a40_should_install_code_server"
  display_name = "Install Code Server"
  description  = "Should Code Server be installed during deploy?"
  default      = 1
  type         = "number"
  icon         = "/icon/code.svg"
  mutable      = true
  option {
    name  = "Yes"
    value = 1
  }
  option {
    name  = "No"
    value = 0
  }
}

data "coder_parameter" "a540_should_install_code_server" {
  name         = "a540_should_install_code_server"
  display_name = "Install Code Server"
  description  = "Should Code Server be installed during deploy?"
  default      = 1
  type         = "number"
  icon         = "/icon/code.svg"
  mutable      = true
  option {
    name  = "Yes"
    value = 1
  }
  option {
    name  = "No"
    value = 0
  }
}

data "coder_parameter" "a550_should_install_docker_ce" {
  name         = "a550_should_install_docker_ce"
  display_name = "Install Docker"
  description  = "Should Docker be installed during deploy?"
  default      = 1
  type         = "number"
  icon         = "/icon/docker.svg"
  mutable      = true
  option {
    name  = "Docker CE + Portainer CE"
    value = 2
  }
  option {
    name  = "Docker CE"
    value = 1
  }
  option {
    name  = "None"
    value = 0
  }
}


data "coder_workspace" "me" {
}

resource "coder_agent" "main" {
  os   = "linux"
  arch = "amd64"
  dir  = "/home/${lower(data.coder_workspace.me.owner)}"
  auth = "token"
  startup_script = <<EOT
  #!/bin/sh
  set -e
  if [ ${data.coder_parameter.a540_should_install_code_server.value} -gt 0 ]; then
    until stat /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml > /dev/null 2> /dev/null; do sleep 1; done
    VSCODE_PROXY_DOMAIN=$(echo $VSCODE_PROXY_URI | sed 's/^https\{0,1\}:\/\///')
    cat /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml | grep -v 'password\:\|auth\:\|proxy-domain:\|app-name:\|bind-addr:' | tee -a /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml.tmp
    echo "auth: none" | tee -a /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml.tmp
    echo "bind-addr: 127.0.0.1:13337" | tee -a /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml.tmp
    echo "proxy-domain: '$VSCODE_PROXY_DOMAIN'" | tee -a /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml.tmp
    echo "app-name: '$CODER_WORKSPACE_NAME'" | tee -a /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml.tmp

    mv /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml.tmp /home/${data.coder_workspace.me.owner}/.config/code-server/config.yaml

    sudo systemctl restart code-server@${data.coder_workspace.me.owner}
  fi

  PROXY_DOMAIN_WWW_DIR=$(echo $VSCODE_PROXY_DOMAIN | sed 's/{{port}}/www/' | awk -F\. '{ for(i=1;i<NF;i++) printf $i"." }' | awk -F\. '{ for(i=NF;i>0;i--) printf $i"/" }')
  if [ ! -f $HOME/www/$PROXY_DOMAIN_WWW_DIR/index.php ]; then
    mkdir -p $HOME/www/$PROXY_DOMAIN_WWW_DIR
    echo "<?php phpinfo();" > $HOME/www/$PROXY_DOMAIN_WWW_DIR/index.php
  fi
  
  EOT

  metadata {
    key          = "cpu"
    display_name = "CPU Usage"
    interval     = 5
    timeout      = 5
    script       = "coder stat cpu"
  }
  metadata {
    key          = "memory"
    display_name = "Memory Usage"
    interval     = 5
    timeout      = 5
    script       = "coder stat mem"
  }
  metadata {
    key          = "home"
    display_name = "Home Usage"
    interval     = 600 # every 10 minutes
    timeout      = 30  # df can take a while on large filesystems
    script       = "coder stat disk --path /home/${lower(data.coder_workspace.me.owner)}"
  }
}

resource "coder_app" "code-server" {
  count        = data.coder_parameter.a540_should_install_code_server.value
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "code-server"
  url          = "http://localhost:13337"
  icon         = "/icon/code.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:13337/healthz"
    interval  = 3
    threshold = 10
  }
}

resource "coder_app" "docker-portainer" {
  count        = data.coder_parameter.a550_should_install_docker_ce.value > 1 ? 1 : 0
  agent_id     = coder_agent.main.id
  slug         = "portainer"
  display_name = "Docker Portainer"
  url          = "http://localhost:9000"
  icon         = "/icon/docker.svg"
  subdomain    = true
  share        = "owner"

  healthcheck {
    url       = "http://localhost:9000/api/system/status"
    interval  = 3
    threshold = 10
  }
}

provider "proxmox" {
  pm_api_url      = var.proxmox_api_url != "" ? var.proxmox_api_url : null
  pm_user         = var.proxmox_api_user
  pm_password     = var.proxmox_api_password

  pm_tls_insecure = tobool(var.proxmox_api_insecure)

  # For debugging Terraform provider errors:
  pm_log_enable = true
  pm_log_file   = "/tmp/terraform-plugin-proxmox.log"
  pm_debug      = true
  pm_log_levels = {
    _default    = "debug"
    _capturelog = ""
  }
}

resource "terraform_data" "coder_workspace_template_version" {
  input = data.coder_workspace.me.template_version
}

resource "terraform_data" "bootstrap_script_base_system" {
  input = <<-EOT
  #!/bin/bash
  set -e

  export DEBIAN_FRONTEND=noninteractive

  # Install base packages if absent
  if ! which sudo git curl wget jq htop nload vim pv > /dev/null; then
    apt update -qq && apt install -yqqq sudo git-core curl wget jq htop nload vim pv gettext
  fi

  # Reconfigure locales
  if grep '# en_US.UTF-8 UTF-8' /etc/locale.gen > /dev/null; then
    dpkg -l | grep 'ii\s\+locales' > /dev/null || apt update -qq && apt install -yqqq locales
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
    dpkg-reconfigure locales  > /dev/null 2>&1
    update-locale LANG=en_US.UTF-8 > /dev/null 2>&1
  fi

  # Create new user if absent
  getent passwd '${local.username}' > /dev/null || {
    adduser \
      --shell /bin/bash \
      --gecos 'User for workspace owner' \
      --disabled-password \
      --home '/home/${local.username}' \
      '${local.username}'
  }

  # Re-configure sudo for user
  usermod -aG sudo ${local.username}
  echo '${local.username} ALL=(ALL) NOPASSWD: ALL' | tee /etc/sudoers.d/${local.username}

  # Create home folder if absent
  [[ ! -d '/home/${local.username}' ]] && {
    mkdir -p '/home/${local.username}'
    chown $(id -u ${local.username}):$(id -g ${local.username}) '/home/${local.username}'
  }

  echo '[Unit]
  Description=Make sure /dev/kmsg exists
  [Service]
  Type=simple
  RemainAfterExit=yes
  ExecStart=/bin/sh -c "[ ! -e /dev/kmsg ] && ln -s /dev/console /dev/kmsg || /usr/bin/true; mount --make-rshared /"
  TimeoutStartSec=0
  [Install]
  WantedBy=default.target' > /etc/systemd/system/kmsg.service

  systemctl enable --now kmsg.service
  EOT
}

resource "terraform_data" "bootstrap_script_app_code_server" {
  input = <<-EOT
  #!/bin/bash
  set -e

  # Installing Code-Server if it's absent
  which code-server > /dev/null || {
    CODE_SERVER_DOWNLOAD_URL=$(curl -sL https://api.github.com/repos/coder/code-server/releases/latest | jq -r '.assets[].browser_download_url' | grep 'amd64.deb')
    curl -fL $CODE_SERVER_DOWNLOAD_URL -o /tmp/code_server.deb
    dpkg -i /tmp/code_server.deb
    rm /tmp/code_server.deb

    systemctl enable --now code-server@${local.username}
  }
  EOT
}

resource "terraform_data" "bootstrap_script_app_docker_ce" {
  input = data.coder_parameter.a550_should_install_docker_ce.value < 1 ? "" : <<-EOT
  #!/bin/bash
  set -e

  # Installing Docker CE and Portainer CE if it's absent
  which docker > /dev/null || {
    # Install Docker CE
    curl https://get.docker.com | bash
    usermod -aG docker ${local.username}
  }
  EOT
}

resource "terraform_data" "bootstrap_script_app_portainer_ce" {
  input = data.coder_parameter.a550_should_install_docker_ce.value < 2 ? "" :<<-EOT
#!/bin/bash
set -e

# Installing Portainer CE if it's absent
[[ ! -e /opt/portainer/portainer ]] && {
  # Install Portainer CE
  PORTAINER_CE_DOWNLOAD_URL=$(curl -sL https://api.github.com/repos/portainer/portainer/releases/latest | jq -r '.assets[].browser_download_url' | grep 'linux-amd64' | grep '.tar.gz')
  mkdir /tmp/portainer_ce && cd /tmp/portainer_ce
  curl -fL $PORTAINER_CE_DOWNLOAD_URL -o portainer_ce.tgz
  tar -zxf portainer_ce.tgz
  mv portainer /opt/portainer
  mkdir /var/lib/portainer
  chown ${local.username} /var/lib/portainer

  echo '[Unit]
  Description=Portainer CE
  After=docker.service
  Wants=docker.service

  [Service]
  User=${local.username}
  ExecStart=/opt/portainer/portainer --bind=127.0.0.1:9000 --data=/var/lib/portainer
  Restart=always
  RestartSec=10
  TimeoutStopSec=90
  KillMode=process

  OOMScoreAdjust=-800
  SyslogIdentifier=portainer

  [Install]
  WantedBy=multi-user.target' > /etc/systemd/system/portainer.service

  systemctl enable --now portainer
}
EOT
}

resource "terraform_data" "bootstrap_script_coder_agent_init" {
  lifecycle {
    replace_triggered_by = [
      terraform_data.coder_workspace_template_version.id
    ]
  }
  input = <<-EOT
    #!/bin/bash
    set -e

    mkdir -p /opt/coder
    echo '${coder_agent.main.init_script}' | tee /opt/coder/init
    chmod 0755 /opt/coder/init

    echo '[Unit]
    Description=Coder Agent
    After=network-online.target
    Wants=network-online.target

    [Service]
    User=${lower(data.coder_workspace.me.owner)}
    ExecStart=/opt/coder/init
    Environment=CODER_AGENT_TOKEN=${coder_agent.main.token}
    Restart=always
    RestartSec=10
    TimeoutStopSec=90
    KillMode=process

    OOMScoreAdjust=-900
    SyslogIdentifier=coder-agent

    [Install]
    WantedBy=multi-user.target' > /etc/systemd/system/coder-agent.service

    systemctl daemon-reload
    systemctl enable coder-agent
    systemctl stop coder-agent
    systemctl start coder-agent
  EOT
}

locals {
  vm_name           = replace("${data.coder_workspace.me.owner}-${data.coder_workspace.me.name}", " ", "_")
  username          = lower(data.coder_workspace.me.owner)
  cpu_cores_count   = data.coder_parameter.a110_cpu_cores_count.value
  memory_size       = data.coder_parameter.a120_memory_size.value
  disk_size         = data.coder_parameter.a130_disk_size.value
}


resource "terraform_data" "bootstrap_script" {
  count = data.coder_workspace.me.transition == "start" ? 1 : 0

  depends_on = [
    terraform_data.bootstrap_script_base_system,
    terraform_data.bootstrap_script_app_code_server,
    terraform_data.bootstrap_script_app_docker_ce,
    terraform_data.bootstrap_script_app_portainer_ce,
    terraform_data.bootstrap_script_coder_agent_init,
  ]

  lifecycle {
    replace_triggered_by = [
      terraform_data.bootstrap_script_coder_agent_init.input,
    ]
  }

  provisioner "file" {
    connection {
      type        = "ssh"
      user        = var.proxmox_ssh_user
      host        = var.proxmox_ssh_host
      port        = var.proxmox_ssh_port
      private_key = file(var.proxmox_ssh_key_path)
    }
    destination = "/tmp/proxmox_lxc_${local.vm_name}_bootstrap.sh"
    content = <<-EOT
    #!/bin/bash
    set -e
    unset LS_COLORS; 
    export DEBIAN_FRONTEND=noninteractive
    export TERM=xterm
    ${terraform_data.bootstrap_script_base_system.input}
    ${terraform_data.bootstrap_script_app_code_server.input}
    ${terraform_data.bootstrap_script_app_docker_ce.input}
    ${terraform_data.bootstrap_script_app_portainer_ce.input}
    ${terraform_data.bootstrap_script_coder_agent_init.input}
    EOT
  }
}

# Provision the Proxmox LXC
resource "proxmox_lxc" "lxc" {
  
  # This VM's data is persistent! 
  # It will stop/start, but is only
  # deleted when the Coder workspace is
  count = 1

  hostname    = local.vm_name
  target_node = var.vm_target_node

  ssh_public_keys = <<-EOT
    ${tls_private_key.rsa_4096.public_key_openssh}
  EOT

  depends_on = [
    terraform_data.bootstrap_script,
    tls_private_key.rsa_4096,
  ]

  # Preserve the network config.
  # see: https://github.com/Telmate/terraform-provider-proxmox/issues/112
  lifecycle {
    ignore_changes = [network, rootfs, mountpoint, ostemplate]
  }

  hastate      = "started"
  ostemplate   = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  unprivileged = true
  cores        = parseint(local.cpu_cores_count, 10)
  memory       = parseint(local.memory_size, 10)

  features {
    nesting = true
  }
  
  // Rootfs mount
  rootfs {
    size    = "${parseint(local.disk_size, 10)}G"
    storage = var.vm_target_storage
  }

  # // Homefs mount
  # mountpoint {
  #   key     = "0"
  #   slot    = 0
  #   mp      = "/home"
  #   size    = "${parseint(local.disk_size, 10)}G"
  #   storage = var.vm_target_storage
  #   backup  = true
  # }

  network {
    name   = "eth0"
    bridge = var.vm_target_bridge
    ip     = "dhcp"
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.proxmox_ssh_user
      host        = var.proxmox_ssh_host
      port        = var.proxmox_ssh_port
      private_key = file(var.proxmox_ssh_key_path)
    }
    inline = [
      "pct status $(pct list | awk '{ print $1\"@\"$3 }' | grep \"@${local.vm_name}$\" | awk -F@ '{print $1}') | grep -v running && pct start $(pct list | awk '{ print $1\"@\"$3 }' | grep \"@${local.vm_name}$\" | awk -F@ '{print $1}') || /bin/true",
      "lxc-wait $(pct list | awk '{ print $1\"@\"$3 }' | grep \"@${local.vm_name}$\" | awk -F@ '{print $1}') -s RUNNING",
      "pct push $(pct list | awk '{ print $1\"@\"$3 }' | grep \"@${local.vm_name}$\" | awk -F@ '{print $1}') /boot/config-$(uname -r) /boot/config-$(uname -r)",
      "pct push $(pct list | awk '{ print $1\"@\"$3 }' | grep \"@${local.vm_name}$\" | awk -F@ '{print $1}') /tmp/proxmox_lxc_${local.vm_name}_bootstrap.sh /bootstrap.sh",
      "pct exec $(pct list | awk '{ print $1\"@\"$3 }' | grep \"@${local.vm_name}$\" | awk -F@ '{print $1}') /bin/bash /bootstrap.sh"
    ]
  }
}

# Start the LXC via ssh and inject updated bootstrap script
resource "null_resource" "start_vm" {
  count      = data.coder_workspace.me.transition == "start" ? 1 : 0

  depends_on = [
    terraform_data.bootstrap_script,
    proxmox_lxc.lxc,
  ]

  lifecycle {
    replace_triggered_by = [
      terraform_data.bootstrap_script_coder_agent_init.input,
    ]
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.proxmox_ssh_user
      host        = var.proxmox_ssh_host
      port        = var.proxmox_ssh_port
      private_key = file(var.proxmox_ssh_key_path)
    }
    inline = [
      "pct status $(pct list | grep \"\\b${local.vm_name}\\b\" | awk '{print $1}') | grep -v running && pct start $(pct list | grep \"\\b${local.vm_name}\\b\" | awk '{print $1}') || /bin/true",
      "lxc-wait $(pct list | grep \"\\b${local.vm_name}\\b\" | awk '{print $1}') -s RUNNING",
      "pct push $(pct list | grep \"\\b${local.vm_name}\\b\" | awk '{print $1}') /tmp/proxmox_lxc_${local.vm_name}_bootstrap.sh /bootstrap.sh",
      "pct exec $(pct list | grep \"\\b${local.vm_name}\\b\" | awk '{print $1}') /bin/bash /bootstrap.sh",
    ]
  }
}

# Stop the LXC via ssh
resource "null_resource" "stop_vm" {

  count = data.coder_workspace.me.transition == "stop" ? 1 : 0

  depends_on = [
    proxmox_lxc.lxc
  ]

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.proxmox_ssh_user
      host        = var.proxmox_ssh_host
      port        = var.proxmox_ssh_port
      private_key = file(var.proxmox_ssh_key_path)
    }
    inline = [
      "pct stop $(pct list | grep \"\\b${local.vm_name}\\b\" | awk '{print $1}')",
      "lxc-wait $(pct list | grep \"\\b${local.vm_name}\\b\" | awk '{print $1}') -s STOPPED",
      "ha-manager remove ct:$(pct list | grep \"\\b${local.vm_name}\\b\" | awk '{print $1}')",
    ]
  }
}
