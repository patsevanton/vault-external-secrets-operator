resource "vault_mount" "kvv2-secret" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}

resource "vault_auth_backend" "approle" {
  type = "approle"
}

resource "vault_policy" "secret-read-policy" {
  name = "read-policy"

  policy = <<EOT
path "secret/postgres" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_approle_auth_backend_role" "secret" {
  backend        = vault_auth_backend.approle.path
  role_name      = "secret"
  token_policies = ["read-policy"]
}


resource "vault_approle_auth_backend_role_secret_id" "id" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.secret.role_name
}

output "role_id" {
  value     = vault_approle_auth_backend_role.secret.role_id
  sensitive = true
}

output "secret_id" {
  value     = vault_approle_auth_backend_role_secret_id.id.secret_id
  sensitive = true
}