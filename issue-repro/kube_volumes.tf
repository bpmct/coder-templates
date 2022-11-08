resource "kubernetes_persistent_volume_claim" "home" {
  metadata {
    name      = "coder-${local.basename}-home"
    namespace = var.namespace
    labels = {
      workspace_name  = local.name
      workspace_owner = local.owner
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${var.home_disk_size}Gi"
      }
    }
  }
  wait_until_bound = false

  # Don't destroy when storage is increased manually
  lifecycle {
    ignore_changes = [
      spec,
    ]
  }
}

resource "kubernetes_persistent_volume_claim" "localstack" {
  metadata {
    name      = "localstack-${local.basename}"
    namespace = var.namespace
    labels = {
      workspace_name  = local.name
      workspace_owner = local.owner
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${var.localstack_disk_size}Gi"
      }
    }
  }
  wait_until_bound = false

  # Don't destroy when storage is increased manually
  lifecycle {
    ignore_changes = [
      spec,
    ]
  }
}

resource "kubernetes_persistent_volume_claim" "postgres" {
  metadata {
    name      = "postgres-${local.basename}"
    namespace = var.namespace
    labels = {
      workspace_name  = local.name
      workspace_owner = local.owner
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "${var.postgres_disk_size}Gi"
      }
    }
  }
  wait_until_bound = false

  # Don't destroy when storage is increased manually
  lifecycle {
    ignore_changes = [
      spec,
    ]
  }
}
