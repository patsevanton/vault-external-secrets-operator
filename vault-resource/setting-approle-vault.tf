resource "vault_mount" "kvv2-secret" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}

# Включение approle из CLI.
resource "vault_auth_backend" "approle" {
  type = "approle"
}

# Создание политики для чтения по пути secret/postgres
resource "vault_policy" "secret-read-policy" {
  name = "read-policy"

  policy = <<EOT
path "secret/data/postgres" {
  capabilities = ["read", "list"]
}
EOT
}

# Создание роль для approle.
resource "vault_approle_auth_backend_role" "secret" {
  backend        = vault_auth_backend.approle.path
  role_name      = "secret"
  token_policies = ["read-policy"]
}

# Создание секретного идентификатора (secret_id)
resource "vault_approle_auth_backend_role_secret_id" "id" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.secret.role_name
}

# Получение id роли approle (role_id)
output "role_id" {
  value     = vault_approle_auth_backend_role.secret.role_id
  sensitive = true
}

# Получение секретного идентификатора (secret_id)
output "secret_id" {
  value     = vault_approle_auth_backend_role_secret_id.id.secret_id
  sensitive = true
}

