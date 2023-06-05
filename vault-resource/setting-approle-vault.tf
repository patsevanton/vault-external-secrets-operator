resource "vault_mount" "kvv2-data" {
  path        = "data"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}

resource "vault_kv_secret_v2" "data-postgres" {
  mount = vault_mount.kvv2-data.path
  name  = "postgres"
  data_json = jsonencode(
    {
      POSTGRES_USER = "admin",
      POSTGRES_PASSWORD = "123456"
    }
  )
}

resource "vault_auth_backend" "approle" {
  type = "approle"
}

resource "vault_policy" "data-read-policy" {
  name = "data-read-policy"

  policy = <<EOT
path "data/*" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_approle_auth_backend_role" "data" {
  backend        = vault_auth_backend.approle.path
  role_name      = "data"
  token_policies = ["app-read-policy"]
}


resource "vault_approle_auth_backend_role_secret_id" "id" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.data.role_name
}

output "role_id" {
  value     = vault_approle_auth_backend_role.data.role_id
  sensitive = true
}

output "secret_id" {
  value     = vault_approle_auth_backend_role_secret_id.id.secret_id
  sensitive = true
}