terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "0.5.3"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.13.1"
    }
  }
}
provider "kubernetes" {
  // Use service account for kube config
  config_path = "/root/.kube/config"
}

provider "coder" {
}

locals {
  name     = lower(data.coder_workspace.me.name)
  owner    = lower(data.coder_workspace.me.owner)
  basename = "${local.owner}-${local.name}"
}
