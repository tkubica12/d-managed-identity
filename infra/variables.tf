variable "location" {
  type        = string
  description = <<-EOT
    The Azure region where resources will be deployed.
    Examples: swedencentral, westeurope, southeastasia
  EOT
  default     = "swedencentral"
}

variable "project_name" {
  type        = string
  description = <<-EOT
    The name of the project used as a prefix for all resources.
    This helps identify and group related resources together.
    Prefer short and alphanumeric names.
  EOT
  default     = "manid"
}

variable "vm_admin_password" {
  type        = string
  sensitive   = true
  description = <<-EOT
    The admin password for the virtual machine.
    Must meet Azure password complexity requirements.
  EOT
}
