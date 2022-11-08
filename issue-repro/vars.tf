variable "namespace" {
  type        = string
  sensitive   = true
  description = "The namespace to create workspaces in (must exist prior to creating workspaces)"
  default     = "coder-workspaces"
}

variable "home_disk_size" {
  type        = number
  description = "Home volume size in GB"
  default     = 10
  validation {
    condition     = var.home_disk_size >= 1 && var.home_disk_size <= 20
    error_message = "Value must be between 1 and 20"
  }
}

variable "localstack_disk_size" {
  type        = number
  description = "Localstack volume size in GB"
  default     = 1
  validation {
    condition     = var.localstack_disk_size >= 1 && var.localstack_disk_size <= 5
    error_message = "Value must be between 1 and 5"
  }
}

variable "postgres_disk_size" {
  type        = number
  description = "PostgreSQL volume size in GB"
  default     = 2
  validation {
    condition     = var.postgres_disk_size >= 1 && var.postgres_disk_size <= 10
    error_message = "Value must be between 1 and 10"
  }
}
