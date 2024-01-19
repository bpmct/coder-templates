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
  default ="ya29.a0AfB_bREPLACETHIS"
}
variable "project_id" {
  description = "Which Google Compute Project should your workspace live in?"
  default     = "adls-REPLACETHIS"
}
variable "service_account" {
  description = "Which Google Compute Project should your workspace live in?"
  default     = "REPLACETHISgserviceaccount.com"
}
variable "tenant" {
  description = "ADLS convention of naming tenants"
  default     = "0010-dev"
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
    name  = "Europe (West)"
    value = "europe-west1-b"
    icon  = "/emojis/1f1ea-1f1fa.png"
  }
}

data "coder_parameter" "machine-type" {
  display_name = "GCP machine type"
  name         = "machine-type"
  type         = "string"
  description  = "GCP machine type"
  mutable      = false
  default      = "e2-medium"
  order        = 2
  option {
    name  = "e2-standard-4"
    value = "e2-standard-4"
  }
  option {
    name  = "e2-standard-2"
    value = "e2-standard-2"
  }
  option {
    name  = "e2-medium"
    value = "e2-medium"
  }
  option {
    name  = "e2-micro"
    value = "e2-micro"
  }
  option {
    name  = "e2-small"
    value = "e2-small"
  }
}

data "coder_parameter" "os" {
  name         = "os"
  display_name = "Windows OS"
  type         = "string"
  description  = "Release of Microsoft Windows Server"
  mutable      = false
  default      = "windows-server-2022-dc-v20230414"
  order        = 3
  option {
    name  = "2022"
    value = "windows-server-2022-dc-v20230414"
  }
  option {
    name  = "2019"
    value = "windows-server-2019-dc-v20230414"
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
  name  = "coder-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}-root"
  type  = "pd-standard"
  zone  = data.coder_parameter.zone.value
  image = "projects/windows-cloud/global/images/${data.coder_parameter.os.value}"
  lifecycle {
    ignore_changes = [image]
  }
}



resource "coder_agent" "main" {
  auth               = "google-instance-identity"
  arch               = "amd64"
  connection_timeout = 300 # the first boot takes some time
  os                 = "windows"
  startup_script     = <<EOF

# Set admin password and enable admin user (must be in this order)
Get-LocalUser -Name "Administrator" | Set-LocalUser -Password (ConvertTo-SecureString -AsPlainText "${local.admin_password}" -Force)
Get-LocalUser -Name "Administrator" | Enable-LocalUser

# Enable RDP
New-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0 -PropertyType DWORD -Force

# Disable NLA
New-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 0 -PropertyType DWORD -Force
New-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "SecurityLayer" -Value 1 -PropertyType DWORD -Force

# Enable RDP through Windows Firewall
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

choco feature enable -n=allowGlobalConfirmation

# Install Myrtille
echo "Downloading Myrtille"
New-Item -ItemType Directory -Force -Path C:\temp
Invoke-WebRequest -Uri "https://github.com/cedrozor/myrtille/releases/download/v2.9.2/Myrtille_2.9.2_x86_x64_Setup.msi" -Outfile c:\temp\myrtille.msi
echo "Download complete"
echo "Installing Myrtille"
Start-Process C:\temp\myrtille.msi -ArgumentList "/quiet"
echo "Intallation complete"

# echo "Starting Myrtille"
# Workaround for myrtile not starting automatically
while (!(Test-Path C:\inetpub\wwwroot\iisstart.htm)) {
  # New-Item -ItemType File -Force -Path C:\inetpub\wwwroot\iisstart.htm
  echo "waiting for myrtille to start"
  Start-Sleep -s 10
}
"<head>
  <meta http-equiv='refresh' content='0; URL=https://${local.redirect_url_1}${local.redirect_url_2}${local.redirect_url_3}'>
</head>" | Out-File -FilePath C:\inetpub\wwwroot\iisstart.htm

echo "Startup script complete"

EOF
}

locals {
  admin_password = "REPLACETHIS"
  redirect_url_1 = "rdp--main--${lower(data.coder_workspace.me.name)}--${lower(data.coder_workspace.me.owner)}."
  redirect_url_2 = split("//", data.coder_workspace.me.access_url)[1]
  redirect_url_3 = "/Myrtille/?__EVENTTARGET=&__EVENTARGUMENT=&server=localhost&user=Administrator&password=${local.admin_password}&connect=Connect%21"
}

resource "google_compute_instance" "dev" {
  zone         = data.coder_parameter.zone.value
  count        = data.coder_workspace.me.start_count
  name         = "coder-${lower(data.coder_workspace.me.owner)}-${lower(data.coder_workspace.me.name)}"
  machine_type = data.coder_parameter.machine-type.value
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
  boot_disk {
    auto_delete = true
    source      = google_compute_disk.root.name
  }


  metadata = {

    windows-startup-script-ps1 = <<EOF

    # Install Chocolatey package manager before
    # the agent starts to use via startup_script
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    # Reload path so sessions include "choco" and "refreshenv"
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    # Install Git and reload path
    choco install -y git
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    # start Coder agent init script (see startup_script above)
    ${coder_agent.main.init_script}

    EOF

  }
}

resource "coder_app" "rdp" {
  agent_id     = coder_agent.main.id
  display_name = "RDP Desktop"
  slug         = "rdp"
  icon         = "https://raw.githubusercontent.com/matifali/logos/main/windows.svg"
  url          = "http://localhost"
  subdomain    = true
  share        = "owner"
  healthcheck {
    url       = "http://localhost"
    interval  = 3
    threshold = 120
  }
}

resource "coder_app" "rdp-docs" {
  agent_id     = coder_agent.main.id
  display_name = "How to use local RDP client"
  slug         = "rdp-docs"
  icon         = "https://raw.githubusercontent.com/matifali/logos/main/windows.svg"
  url          = "https://coder.com/docs/v2/latest/ides/remote-desktops#rdp-desktop"
  external     = true
}

resource "coder_metadata" "workspace_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = google_compute_instance.dev[0].id
  item {
    key       = "Administrator password"
    value     = local.admin_password
    sensitive = true
  }
  item {
    key   = "zone"
    value = data.coder_parameter.zone.value
  }
  item {
    key   = "machine-type"
    value = data.coder_parameter.machine-type.value
  }
  item {
    key   = "windows os"
    value = data.coder_parameter.os.value
  }
}