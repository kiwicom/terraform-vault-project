locals {
  runtime_maintainer_groups = concat(var.maintainer_groups, var.runtime_maintainer_groups)
}

data "vault_policy_document" "runtime" {
  rule {
    path = "kw/secret/${local.gitlab_project_path}/runtime/*"
    capabilities = ["read", "list"]
  }
  rule {
    path = "kw/secret/data/${local.gitlab_project_path}/runtime/*"
    capabilities = ["read"]
  }
  rule {
    path = "kw/secret/metadata/${local.gitlab_project_path}/runtime/*"
    capabilities = ["read", "list"]
  }
}

resource "vault_policy" "runtime" {
  count  = var.create_runtime ? 1 : 0
  name   = "kw/secret/${local.gitlab_project_path}/runtime"
  policy = data.vault_policy_document.runtime.hcl
}

data "vault_identity_group" "runtime" {
  for_each   = toset(var.runtime_use_groups)
  group_name = each.value
}

# devs read policy
resource "vault_identity_group_policies" "runtime" {
  for_each  = toset(var.runtime_use_groups)
  group_id  = data.vault_identity_group.runtime[each.value].group_id
  policies  = [vault_policy.runtime[0].name]
  exclusive = false
}

resource "vault_policy" "runtime_maintainers" {
  count  = var.create_runtime ? 1 : 0
  name   = "kw/secret/${local.gitlab_project_path}/runtime-maintainers"
  policy = <<EOT
# access namespace, stage specific secrets
path "kw/secret/${local.gitlab_project_path}/runtime/*" {
  capabilities = ["create", "update", "read", "delete", "list"]
}
path "kw/secret/data/${local.gitlab_project_path}/runtime/*" {
  capabilities = ["create", "update", "read", "delete"]
}
path "kw/secret/metadata/${local.gitlab_project_path}/runtime/*" {
  capabilities = ["create", "update", "read", "delete", "list"]
}
EOT
}

data "vault_identity_group" "runtime_maintainers" {
  for_each   = toset(local.runtime_maintainer_groups)
  group_name = each.value
}

resource "vault_identity_group_policies" "runtime_maintainers" {
  for_each  = toset(local.runtime_maintainer_groups)
  group_id  = data.vault_identity_group.runtime_maintainers[each.value].group_id
  policies  = [vault_policy.runtime_maintainers[0].name]
  exclusive = false
}
