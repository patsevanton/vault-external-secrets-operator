resource "vault_mount" "kv-v2-app" {
  path        = "app"
  type        = "kv-v2"
  description = "kv version 2 secret engine for app"
}
