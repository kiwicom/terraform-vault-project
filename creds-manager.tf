# provided_roles

locals {
  provided_roles = var.main_module_switch ? var.provided_roles : {}
  stage_roles = flatten([for stage in keys(local.provided_roles) : formatlist("%s/creds/%s", stage, local.provided_roles[stage])])
}

data "vault_policy_document" "creds_maintainers" {
  for_each = toset(keys(local.provided_roles))
  rule {
    description  = "Manage creds kv1"
    path         = "kw/secret/${local.gitlab_project_path}/${each.key}/creds/*"
    capabilities = ["create", "update", "read", "delete", "list"]
  }
  rule {
    description  = "Manage creds kv2"
    path         = "kw/secret/data/${local.gitlab_project_path}/${each.key}/creds/*"
    capabilities = ["create", "update", "read", "delete", ]
  }
  rule {
    description  = "Manage creds kv2"
    path         = "kw/secret/metadata/${local.gitlab_project_path}/${each.key}/creds/*"
    capabilities = ["create", "update", "read", "delete", "list"]
  }
}

resource "vault_policy" "creds_maintainer" {
  for_each = toset(keys(local.provided_roles))
  name     = "kw/secret/${local.gitlab_project_path}/${each.key}/creds-maintainer"
  policy   = data.vault_policy_document.creds_maintainers[each.key].hcl
}

data "vault_policy_document" "provided_roles" {
  for_each = toset(local.stage_roles)
  rule {
    description  = "Access creds kv1"
    path         = "kw/secret/${local.gitlab_project_path}/${each.value}"
    capabilities = ["read", "list"]
  }
  rule {
    description  = "Access creds kv2"
    path         = "kw/secret/data/${local.gitlab_project_path}/${each.value}"
    capabilities = ["read", ]
  }
  rule {
    description  = "Access creds kv2"
    path         = "kw/secret/metadata/${local.gitlab_project_path}/${each.value}"
    capabilities = ["read", ]
  }
}

resource "vault_policy" "roles" {
  for_each = toset(local.stage_roles)
  name     = "kw/secret/${local.gitlab_project_path}/${each.value}"
  policy   = data.vault_policy_document.provided_roles[each.value].hcl
}

output "roles_policies" {
  value = [for policy in vault_policy.roles : policy.name]
}
