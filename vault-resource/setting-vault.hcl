resource "vault_mount" "kv-v2-app" {
  path        = "app"
  type        = "kv-v2"
  description = "kv version 2 secret engine for app"
}

resource "vault_generic_secret" "example" {
  path = "secret/foo"

  data_json = <<EOT
{
  "foo":   "bar",
  "pizza": "cheese"
}
EOT
}
