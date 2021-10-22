locals {
  runtime_maintainer_groups = var.main_module_switch ? concat(var.maintainer_groups, var.runtime_maintainer_groups) : []
  runtime_use_groups        = var.main_module_switch ? var.runtime_use_groups : []
}

data "vault_policy_document" "runtime" {
  rule {
    path         = "kw/secret/data/${local.gitlab_project_path}/runtime/*"
    capabilities = ["read"]
  }
  rule {
    path         = "kw/secret/metadata/${local.gitlab_project_path}/runtime/*"
    capabilities = ["read", "list"]
  }
}

resource "vault_policy" "runtime" {
  count  = var.main_module_switch && var.create_runtime ? 1 : 0
  name   = "kw/secret/${local.gitlab_project_path}/runtime"
  policy = data.vault_policy_document.runtime.hcl
}

data "vault_identity_group" "runtime" {
  for_each   = toset(local.runtime_use_groups)
  group_name = each.value
}

# devs read policy
resource "vault_identity_group_policies" "runtime" {
  for_each  = toset(local.runtime_use_groups)
  group_id  = data.vault_identity_group.runtime[each.value].group_id
  policies  = [vault_policy.runtime[0].name]
  exclusive = false
}

locals {
  runtime_path_parts = split("/", "${local.gitlab_project_path}/runtime")
}

data "vault_policy_document" "runtime_maintainers" {
  rule {
    capabilities = ["create", "update", "read", "delete", "list"]
    path         = "kw/secret/data/${local.gitlab_project_path}/runtime/*"
  }

  rule {
    capabilities = ["create", "update", "read", "delete", "list"]
    path         = "kw/secret/metadata/${local.gitlab_project_path}/runtime/*"
  }

  dynamic "rule" {
    for_each = local.runtime_path_parts
    content {
      path         = "kw/secret/metadata/${join("/", slice(local.runtime_path_parts, 0, rule.key))}"
      capabilities = ["list"]
      description  = "list of subpath"
    }
  }
}

resource "vault_policy" "runtime_maintainers" {
  count  = var.main_module_switch && var.create_runtime ? 1 : 0
  name   = "kw/secret/${local.gitlab_project_path}/runtime-maintainers"
  policy = data.vault_policy_document.runtime_maintainers.hcl
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
