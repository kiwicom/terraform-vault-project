# terraform-vault-project

Vault resources for Gitlab project. 

## Runtime secrets

- creates "use" and "maintainers" policies for the path `kw/secret/[GITLAB_PATH]/runtime/*` in this 
 case: `kw/secret/automation/granny/runtime/*` with same name (eventually with `-maintainers` suffix for maintainer policy)
- if `runtime_maintainer_groups` or `maintainer_groups` are specified they will get the runtime maintainer policy assigned
- if `runtime_use_groups` is specified the groups will get "use" policy assigned - it usually does not make sense to 
 assign policies here - we have special module for this
- let's say the application will run in `test-tom` cluster in `tom-based-app` namespace, so we assign
 `kw/secret/automation/granny/runtime` to the namespace

```hcl
module "project_automation_granny" {
  source  = "kiwicom/project/vault"
  version = "1.0.0"

  # automation/granny
  project_id = 684

  runtime_use_groups = [
    "engineering.automation"
  ]

  runtime_maintainer_groups = [
    "engineering.automation-seniors"
  ]
}

# Namespace module extension
module "ns_tom_based_app" {
  source  = "kiwicom/namespace/kubernetes"
  version = "~> 3.0.0"
...
  additional_policies = [
    "kw/secret/automation/granny/runtime",
  ]
}

```

## Simple CICD

- `infra/bi/tf-db-roles` is infrastructure repo so runtime secrets don't make sense
- it needs special permission which is assigned in `cicd_additinal_policies`
- it creates special `approle` role for the CICD of this project `kw_search-team_katana_cicd` note: slashes are replaced
 by underscores, but it is always the same `kw_[GITLAB_PATH_UNDERSCORED]_cicd`
- role_id and secret_id are passed to Gitlab Env Vars

```hcl
module "project_infra_bi_tf_db_roles" {
  source  = "kiwicom/project/vault"
  version = "1.0.0"

  # infra/bi/tf-db-roles
  project_id     = 2845
  create_runtime = false

  cicd_additinal_policies = [
    "kw/personal-secrets-write"
  ]
}
```

## More comlex setup
- `bad_practice_cicd_static_path = true` creates policies for static CICS secrets on path `kw/secret/[GITLAB_PATH]/cicd/*`
 with all corresponding "use" and "maintainers" policies, groups and assignments
- static secrets for CICD in a vault are considered bad practice because Gitlab itself provides better granularity
 (can distinguish between normal and protected branches) and it can also mask the secrets in outputs
- `cicd_use_groups` is also bad practice because you usually do not want devs to act like CICD
- CICD maintainer policy will be assigned to merge of `maintainer_groups` and `cicd_maintainer_groups`
- in `cicd_additinal_policies` you can assign for example access to DB. So CICD can run tests against sandbox DB or
 you can run DB migrations in CICD (I personally do not like the idea).

```hcl
module "project_search_team_katana" {
  source  = "kiwicom/project/vault"
  version = "1.0.0"

  # search-team/katana
  project_id                    = 528
  bad_practice_cicd_static_path = true

  cicd_use_groups = [
    "engineering.search-backend.python-seniors"
  ]

  # access to both runtime and cicd
  maintainer_groups = [
    "engineering.search-backend.python-seniors"
  ]

  cicd_maintainer_groups = [
    "engineering.search-backend-seniors"
  ]

  cicd_additinal_policies = [
    "kw/infra/platform/temporary/istio-test-tom/th-tom/creds/ro"
  ]
}
```
