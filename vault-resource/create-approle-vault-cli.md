
- Войдите в систему из командной строки с помощью своего корневого токена
```shell
$ vault login
Token (will be hidden): 
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                hvs.NkWkXPiUFsy0RM69lZokLUu8
token_accessor       85xbbBELOjTQo7PdXPHdsGEB
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
```

- Мы будем использовать этот Token для подключения к hashicorp vault.

- Включите engine kv из CLI.
```shell
vault secrets enable -version=2 -path=data kv
```

Terraform код включения engine kv.
```hcl
resource "vault_mount" "kvv2-data" {
  path        = "data"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}
```

- Создайте секрет из CLI.
```shell
vault kv put data/postgres POSTGRES_USER=admin POSTGRES_PASSWORD=123456
```

Terraform код создания секрета. Но лучше секреты в коде не держать.
```hcl
resource "vault_kv_secret_v2" "example" {
  mount = vault_mount.kvv2-data.path
  name  = "secret"
  data_json = jsonencode(
    {
      POSTGRES_USER = "admin",
      POSTGRES_PASSWORD = "123456"
    }
  )
}
```

- Посмотрите ваши текущие секреты.
```shell
$ vault secrets list
Path          Type         Accessor              Description
----          ----         --------              -----------
cubbyhole/    cubbyhole    cubbyhole_fc3b7606    per-token private secret storage
data/         kv           kv_925ebd04           KV Version 2 secret engine mount
identity/     identity     identity_f9561de2     identity store
sys/          system       system_fc5b17f1       system endpoints used for control, policy and debugging
```

- Включите approle из CLI.
```shell
vault auth enable approle
```

Terraform код включения approle.
```hcl
resource "vault_auth_backend" "approle" {
  type = "approle"
}
```

- Создайте политику для чтения по пути app/*
```shell
vault policy write read-policy -<<EOF
path "data/*" {
capabilities = [ "read", "list" ]
}
EOF
```

Terraform код создания политики для чтения по пути app/*
```hcl
resource "vault_policy" "read-policy" {
  name = "read-policy"

  policy = <<EOT
path "data/*" {
  capabilities = ["read", "list"]
}
EOT
}
```

- Создайте роль для approle.
```shell
vault write auth/approle/role/data token_policies="read-policy"
```

Terraform код создания роли для approle.
```hcl
resource "vault_approle_auth_backend_role" "data" {
  backend        = vault_auth_backend.approle.path
  role_name      = "data"
  token_policies = ["read-policy"]
}
```


- Посмотрите политику
```shell
vault read auth/approle/role/data
```


- Получите идентификатор роли approle (role_id)
```shell
$ vault read auth/approle/role/data/role-id
Key        Value
---        -----
role_id    c927b91b-16f5-83c1-8736-953a51395b43
```


- Создайте и получите секретный идентификатор (secret_id)
```shell
$ vault write -force auth/approle/role/data/secret-id
Key                   Value
---                   -----
secret_id             8f3312cb-ab4d-c090-16a6-11efdf7ed21a
secret_id_accessor    06134d7c-0c50-d1ab-0931-9c55ba9c6518
secret_id_num_uses    0
secret_id_ttl         0s
```

Terraform код создания секретного идентификатора (secret_id)
```hcl
resource "vault_approle_auth_backend_role_secret_id" "id" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.data.role_name
}
```


Terraform код получения секретного идентификатора (secret_id) через terraform output
```hcl
output "secret_id" {
  value     = vault_approle_auth_backend_role_secret_id.id.secret_id
  sensitive = true
}
```


### Проверяем, работает ли approle или нет
- Войдите в систему, используя свою approle
```shell
vault write auth/approle/login role_id="c927b91b-16f5-83c1-8736-953a51395b43" \
secret_id="8f3312cb-ab4d-c090-16a6-11efdf7ed21a"
```


- Посмотрите ваши текущие секреты.
```shell
vault kv list data
```


- Прочитайте секрет.
```shell
vault kv get data/postgres
```