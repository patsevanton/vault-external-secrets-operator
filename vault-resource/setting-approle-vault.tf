resource "vault_mount" "kvv2-app" {
  path        = "app"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}

resource "vault_kv_secret_v2" "example" {
  mount = vault_mount.kvv2-app.path
  name  = "secret"
  data_json = jsonencode(
    {
      foo = "bar"
    }
  )
}

resource "vault_auth_backend" "approle" {
  type = "approle"
}

resource "vault_policy" "app-read-policy" {
  name = "app-read-policy"

  policy = <<EOT
path "app/*" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_approle_auth_backend_role" "app" {
  backend        = vault_auth_backend.approle.path
  role_name      = "app"
  token_policies = ["app-read-policy"]
}


resource "vault_approle_auth_backend_role_secret_id" "id" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.app.role_name
}

output "role_id" {
  value     = vault_approle_auth_backend_role.app.role_id
  sensitive = true
}

output "secret_id" {
  value     = vault_approle_auth_backend_role_secret_id.id.secret_id
  sensitive = true
}