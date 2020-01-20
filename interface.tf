variable "project_id" {
  type        = string
  description = "GitLab project ID"
}

variable "bad_practice_cicd_static_path" {
  default     = false
  description = "Should be CICD policies and resources created - mostly bad practice"
}

variable "create_runtime" {
  default     = true
  description = "Should be runtime policy created"
}

variable "maintainer_groups" {
  default     = []
  description = "Whom to assign permissions to manage Runtime and CICD secrets"
}

variable "cicd_additinal_policies" {
  default     = []
  description = "Additional policies to assign to CICD of the project"
}

variable "cicd_use_groups" {
  default     = []
  description = "Usually you do not want this. But you can allow some group to act as an CICD."
}

variable "cicd_maintainer_groups" {
  default     = []
  description = "You can have different maintainers of Runtime and CICD secrets."
}

variable "runtime_use_groups" {
  default     = []
  description = "Usually developers needs to access runtime secrets for development."
}

variable "runtime_maintainer_groups" {
  default     = []
  description = "You can have different maintainers of Runtime and CICD secrets."
}

variable "provided_roles" {
  default     = {}
  description = "App as secrets manager"
}

variable "cicd_variable_prefix" {
  default     = "TF_VAR_VAULT_ENTERPRISE_"
  description = "Prefix for Gitlab CICD variables"
}

output "cicd_role_id" {
  value = length(local.cicd_policies) < 1 ? "" : vault_approle_auth_backend_role.cicd[0].role_id
}

output "cicd_secret_id" {
  value = length(local.cicd_policies) < 1 ? "" : vault_approle_auth_backend_role_secret_id.cicd[0].secret_id
}
