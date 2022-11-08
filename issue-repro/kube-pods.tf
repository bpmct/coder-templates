# resource "kubernetes_job" "prepare-home" {
#   metadata {
#     name      = "coder-${local.basename}-pre"
#     namespace = var.namespace
#     labels = {
#       k8s-app         = "coder-workspace"
#       workspace_name  = local.name
#       workspace_owner = local.owner
#       workspace_type  = "nodejs"
#     }
#   }
#   spec {
#     template {
#       metadata {
#         labels = {
#           k8s-app         = "coder-workspace"
#           workspace_name  = local.name
#           workspace_owner = local.owner
#           workspace_type  = "nodejs"
#         }
#       }
#       spec {

#         security_context {
#           run_as_user = "1000"
#           fs_group    = "1000"
#         }

#         container {
#           name              = "prepare-home"
#           image             = "codercom/enterprise-base:ubuntu"
#           image_pull_policy = "Always"
#           command           = ["bash", "/usr/share/prepare-home.sh"]
#           volume_mount {
#             mount_path = "/home/coder"
#             name       = "home"
#             read_only  = false
#           }
#           resources {
#             limits = {
#               cpu    = "1"
#               memory = "1Gi"
#             }
#             requests = {
#               cpu    = "100m"
#               memory = "128m"
#             }
#           }
#         }
#         restart_policy = "Never"

#         volume {
#           name = "home"
#           persistent_volume_claim {
#             claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
#             read_only  = false
#           }
#         }
#       }
#     }
#     backoff_limit = 4
#   }
#   wait_for_completion = true
#   # Pulling image can take ~1mn
#   timeouts {
#     create = "5m"
#     update = "5m"
#   }

#   lifecycle {
#     ignore_changes = [
#       spec,
#     ]
#   }
# }

resource "kubernetes_deployment" "main" {
  metadata {
    name      = "coder-${local.basename}"
    namespace = var.namespace
    labels = {
      workspace_name  = local.name
      workspace_owner = local.owner
    }
  }

  spec {
    strategy {
      type = "Recreate"
    }
    replicas = data.coder_workspace.me.start_count
    selector {
      match_labels = {
        k8s-app         = "coder-workspace"
        workspace_name  = local.name
        workspace_owner = local.owner
      }
    }

    template {
      metadata {
        labels = {
          k8s-app         = "coder-workspace"
          workspace_name  = local.name
          workspace_owner = local.owner
          workspace_type  = "ruby"
        }
        annotations = {}
      }

      spec {
        security_context {
          run_as_user = "1000"
          fs_group    = "1000"
        }

        init_container {
          name    = "setup"
          image   = "codercom/enterprise-base:ubuntu"
          command = ["/usr/bin/sleep", "2"]

          security_context {
            run_as_user = "1000"
          }

          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }

          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
            read_only  = false
          }

          resources {
            limits = {
              cpu    = "1"
              memory = "1Gi"
            }
            requests = {
              cpu    = "100m"
              memory = "128m"
            }
          }
        }

        container {
          name              = "coder"
          image             = "codercom/enterprise-base:ubuntu"
          image_pull_policy = "Always" # default with "latest" tag, but we're not using it
          command = [
            "sh",
            "-c",
            coder_agent.main.init_script
          ]

          security_context {
            run_as_user = "1000"
          }

          env {
            name  = "CODER_AGENT_TOKEN"
            value = coder_agent.main.token
          }

          env {
            name  = "DATABASE_URL"
            value = "postgres://coder:coder@postgres-${local.basename}.${var.namespace}.svc/coder"
          }

          volume_mount {
            mount_path = "/home/coder"
            name       = "home"
            read_only  = false
          }

          resources {
            limits = {
              cpu    = "4"
              memory = "4Gi"
            }
            requests = {
              cpu    = "250m"
              memory = "1Gi"
            }
          }
        }

        container {
          name  = "localstack"
          image = "localstack/localstack:1.1.0"

          security_context {
            run_as_user = "1000"
          }

          port {
            name           = "edgeservices"
            container_port = 4566
            protocol       = "TCP"
          }

          port {
            name           = "apiservices"
            container_port = 4571
            protocol       = "TCP"
          }

          env {
            name  = "PERSISTENCE"
            value = "1"
          }

          env {
            name  = "LOCALSTACK_VOLUME_DIR"
            value = "/var/lib/localstack"
          }

          resources {
            limits = {
              cpu    = "1"
              memory = "1Gi"
            }
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
          }

          volume_mount {
            mount_path = "/var/lib/localstack"
            name       = "localstack"
            read_only  = false
          }
        }

        container {
          name              = "redis"
          image             = "redis:6"
          image_pull_policy = "Always"

          security_context {
            run_as_user = "1000"
          }

          port {
            name           = "redis"
            container_port = 6379
            protocol       = "TCP"
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }
        }

        volume {
          name = "home"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.home.metadata.0.name
            read_only  = false
          }
        }

        volume {
          name = "localstack"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.localstack.metadata.0.name
            read_only  = false
          }
        }
      }
    }
  }
  #   depends_on = [kubernetes_job.prepare-home]
}


resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "postgres-${local.basename}"
    namespace = var.namespace
    labels = {
      workspace_name  = local.name
      workspace_owner = local.owner
    }
  }

  spec {
    strategy {
      type = "Recreate"
    }
    replicas = data.coder_workspace.me.start_count
    selector {
      match_labels = {
        k8s-app         = "postgresql"
        workspace_name  = local.name
        workspace_owner = local.owner
      }
    }

    template {
      metadata {
        labels = {
          k8s-app         = "postgresql"
          workspace_name  = local.name
          workspace_owner = local.owner
        }
        annotations = {}
      }

      spec {

        container {
          name              = "postgres"
          image             = "postgres:13-bullseye"
          image_pull_policy = "Always"

          env {
            name  = "POSTGRES_USER"
            value = "coder"
          }

          env {
            name  = "POSTGRES_PASSWORD"
            value = "coder"
          }

          env {
            name  = "POSTGRES_DB"
            value = "coder"
          }

          port {
            name           = "postgres"
            container_port = 5432
            protocol       = "TCP"
          }

          resources {
            limits = {
              cpu    = "1"
              memory = "512Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          volume_mount {
            mount_path = "/var/lib/postgresql"
            name       = "postgres"
            read_only  = false
          }
        }

        volume {
          name = "postgres"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres.metadata.0.name
            read_only  = false
          }
        }
      }
    }
  }
  #   depends_on = [kubernetes_job.prepare-home]
}

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgres-${local.basename}"
    namespace = var.namespace
    labels = {
      k8s-app         = "postgresql"
      workspace_name  = local.name
      workspace_owner = local.owner
    }
  }
  spec {
    selector = {
      k8s-app         = "postgresql"
      workspace_name  = local.name
      workspace_owner = local.owner
    }
    port {
      port = 5432
    }

    type = "ClusterIP"
  }
}
