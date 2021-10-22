# - CICD secrets - `kw/secret/[gitlab_path]/application/*`
# - CICD approle `approle/role/[gitlab_path_cammel]_cicd`
# - CICD policy - `kw/[gitlab_path]/application`
# - CICD maintainer policy - `kw/[gitlab_path]/cicd_maintainer`
locals {
  gitlab_project_count = var.project_id != null ? 1 : 0
  gitlab_group_count   = var.group_id != null ? 1 : 0
}

data "gitlab_project" "project" {
  count = local.gitlab_project_count

  id = var.project_id
}

data "gitlab_group" "group" {
  count = local.gitlab_group_count

  id = var.group_id
}

locals {
  approle_path              = "approle"
  gitlab_project_path       = replace(data.gitlab_project.project.web_url, "https://gitlab.skypicker.com/", "")
  gitlab_project_path_camel = replace(local.gitlab_project_path, "/", "_")
  static_secrets_policies   = var.main_module_switch && var.bad_practice_cicd_static_path ? [vault_policy.cicd[0].name] : []
  cicd_default_policies     = ["approle-token"]
  cicd_policies             = var.main_module_switch ? concat(var.cicd_additional_policies, local.static_secrets_policies) : []
  cicd_maintainer_groups    = var.main_module_switch && var.bad_practice_cicd_static_path ? concat(var.maintainer_groups, var.cicd_maintainer_groups) : []
  cicd_use_groups           = var.main_module_switch ? var.cicd_use_groups : []
}

# TODO load policies via data to ensure it exists

resource "vault_approle_auth_backend_role" "cicd" {
  count          = var.main_module_switch && length(local.cicd_policies) > 0 ? 1 : 0
  backend        = local.approle_path
  role_name      = "kw_${local.gitlab_project_path_camel}_cicd"
  token_policies = distinct(concat(local.cicd_policies, local.cicd_default_policies))
  token_ttl      = 3600
}

resource "vault_approle_auth_backend_role_secret_id" "cicd" {
  count     = var.main_module_switch && length(local.cicd_policies) > 0 ? 1 : 0
  role_name = vault_approle_auth_backend_role.cicd[0].role_name
}

resource "gitlab_project_variable" "role_id" {
  count             = var.main_module_switch && length(local.cicd_policies) > 0 ? local.gitlab_project_count : 0
  project           = data.gitlab_project.project.0.id
  key               = "${var.cicd_variable_prefix}ROLE_ID"
  value             = vault_approle_auth_backend_role.cicd[0].role_id
  masked            = true
  environment_scope = "*"
}

resource "gitlab_project_variable" "secret_id" {
  count             = var.main_module_switch && length(local.cicd_policies) > 0 ? local.gitlab_project_count : 0
  project           = data.gitlab_project.project.0.id
  key               = "${var.cicd_variable_prefix}SECRET_ID"
  value             = vault_approle_auth_backend_role_secret_id.cicd[0].secret_id
  masked            = true
  environment_scope = "*"
}

resource "gitlab_group_variable" "role_id" {
  count  = var.main_module_switch && length(local.cicd_policies) > 0 ? local.gitlab_group_count : 0
  group  = data.gitlab_group.group.0.id
  key    = "${var.cicd_variable_prefix}ROLE_ID"
  value  = vault_approle_auth_backend_role.cicd[0].role_id
  masked = true
}

resource "gitlab_group_variable" "secret_id" {
  count  = var.main_module_switch && length(local.cicd_policies) > 0 ? local.gitlab_group_count : 0
  group  = data.gitlab_project.project.id
  key    = "${var.cicd_variable_prefix}SECRET_ID"
  value  = vault_approle_auth_backend_role_secret_id.cicd[0].secret_id
  masked = true
}

# the bad practice thingy:
resource "vault_policy" "cicd" {
  count  = var.main_module_switch && var.bad_practice_cicd_static_path ? 1 : 0
  name   = "kw/secret/${local.gitlab_project_path}/cicd"
  policy = <<EOT
# access namespace, stage specific secrets
path "kw/secret/${local.gitlab_project_path}/cicd/*" {
  capabilities = ["read", "list"]
}
path "kw/secret/data/${local.gitlab_project_path}/cicd/*" {
  capabilities = ["read"]
}
path "kw/secret/metadata/${local.gitlab_project_path}/cicd/*" {
  capabilities = ["read", "list"]
}
EOT
}


data "vault_identity_group" "cicd" {
  for_each   = toset(local.cicd_use_groups)
  group_name = each.value
}

# devs read policy
resource "vault_identity_group_policies" "cicd" {
  for_each  = toset(local.cicd_use_groups)
  group_id  = data.vault_identity_group.cicd[each.value].group_id
  policies  = local.cicd_policies
  exclusive = false
}

locals {
  cicd_path_parts = split("/", "${local.gitlab_project_path}/cicd")
}

data "vault_policy_document" "cicd" {
  rule {
    capabilities = ["create", "update", "read", "delete", "list"]
    path         = "kw/secret/data/${local.gitlab_project_path}/cicd/*"
  }

  rule {
    capabilities = ["create", "update", "read", "delete", "list"]
    path         = "kw/secret/metadata/${local.gitlab_project_path}/cicd/*"
  }

  dynamic "rule" {
    for_each = local.cicd_path_parts
    content {
      path         = "kw/secret/metadata/${join("/", slice(local.cicd_path_parts, 0, rule.key))}"
      capabilities = ["list"]
      description  = "list of subpath"
    }
  }
}

resource "vault_policy" "cicd_maintainers" {
  count  = var.main_module_switch && var.bad_practice_cicd_static_path ? 1 : 0
  name   = "kw/secret/${local.gitlab_project_path}/cicd-maintainers"
  policy = data.vault_policy_document.cicd.hcl
}

data "vault_identity_group" "cicd_maintainers" {
  for_each   = toset(local.cicd_maintainer_groups)
  group_name = each.value
}

resource "vault_identity_group_policies" "cicd_maintainers" {
  for_each  = toset(local.cicd_maintainer_groups)
  group_id  = data.vault_identity_group.cicd_maintainers[each.value].group_id
  policies  = [vault_policy.cicd_maintainers[0].name]
  exclusive = false
}
