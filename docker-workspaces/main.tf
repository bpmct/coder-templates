
terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.4.1"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.16.0"
    }
  }
}

# Admin parameters
variable "step1_docker_host" {
  description = <<-EOF
  Docker host URL (SSH or TCP)

  See: https://registry.terraform.io/providers/kreuzwerker/docker/latest/docs#example-usage
  EOF
  sensitive = true
}
variable "step2_arch" {
  description = "arch: What architecture is your Docker host on?"
  validation {
    condition     = contains(["amd64", "arm64", "armv7"], var.step2_arch)
    error_message = "Value must be amd64, arm64, or armv7."
  }
  sensitive = true
}
variable "step3_OS" {
  description = <<-EOF
  What operating system is your Coder host on?
  EOF

  validation {
    condition     = contains(["MacOS", "Windows", "Linux"], var.step3_OS)
    error_message = "Value must be MacOS, Windows, or Linux."
  }
  sensitive = true
}

# TODO: replace with a TAG variable which Coder can interact with
# blocked by 
locals {
  tag = formatdate("DDMMMYYYYhhmm", timestamp())
}

provider "docker" {
  host = var.step1_docker_host
}

provider "coder" {
}

data "coder_workspace" "me" {
}

variable "docker_image" {
  description = "What Docker image would you like to use for your workspace?"
  default     = "base"

  # List of images available for the user to choose from.
  # Delete this condition to give users free text input.
  validation {
    condition     = contains(["base", "java", "node", "golang"], var.docker_image)
    error_message = "Invalid Docker image!"
  }

  # Prevents admin errors when the image is not found
  validation {
    condition     = fileexists("images/${var.docker_image}.Dockerfile")
    error_message = "Invalid Docker image. The file does not exist in the images directory."
  }
}

variable dotfiles_uri {
  description = <<-EOF
  Optional: enter dotfiles repo URI
  EOF

  default = ""
}

resource "coder_agent" "dev" {
  arch = var.step2_arch
  os   = "linux"
  startup_script = var.dotfiles_uri != "" ? "/bin/sh coder dotfiles -y ${var.dotfiles_uri}" : null
}

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}-root"
}

resource "docker_image" "coder_image" {
  name = "coder-base-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
  build {
    path       = "./images/"
    dockerfile = "${var.docker_image}.Dockerfile"
    tag        = ["coder-${var.docker_image}:${local.tag}"]
    build_arg = {
      CODER_BASE_TAG: "v0.1"
    }
  }

  # Keep alive for other workspaces to use upon deletion
  keep_locally = true
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.coder_image.latest
  # Uses lower() to avoid Docker restriction on container names.
  name = "coder-${data.coder_workspace.me.owner}-${lower(data.coder_workspace.me.name)}"
  # Hostname makes the shell more user friendly: coder@my-workspace:~$
  hostname = lower(data.coder_workspace.me.name)
  dns      = ["1.1.1.1"]
  # Use the docker gateway if the access URL is 127.0.0.1 
  command = ["sh", "-c", replace(coder_agent.dev.init_script, "127.0.0.1", "host.docker.internal")]
  env     = ["CODER_AGENT_TOKEN=${coder_agent.dev.token}"]
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
  volumes {
    container_path = "/home/coder/"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
}
