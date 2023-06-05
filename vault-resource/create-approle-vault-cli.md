
- Войдите в систему из командной строки с помощью своего корневого токена
```shell
$ vault login
Token (will be hidden): 
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                hvs.pPEDt7A7JcpqTXYDI7Esk8iW
token_accessor       Dinm9BngAbEDAj8gEpFtoAI2
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
```

- Мы будем использовать этот Token для подключения к hashicorp vault.

- Включите engine kv из CLI.
```shell
vault secrets enable -version=2 -path=app kv
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

- Посмотрите ваши текущие секреты.
```shell
vault secrets list
```

- Создайте секрет из CLI.
```shell
vault kv put data/postgres foo=bar
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
$vault policy write read-policy -<<EOF
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
vault write auth/approle/role/app token_policies="read-policy"
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
$vault read auth/approle/role/data/role-id

Key     Value
---     -----
role_id 675a50e7-cfe0-be76-e35f-49ec009731ea
```


- Создайте и получите секретный идентификатор (secret_id)
```shell
 $vault write -force auth/approle/role/app/secret-id

Key                 Value
---                 -----
secret_id           ed0a642f-2acf-c2da-232f-1b21300d5f29
secret_id_accessor  a240a31f-270a-4765-64bd-94ba1f65703c
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
vault write auth/approle/login role_id="675a50e7-cfe0-be76-e35f-49ec009731ea" \
secret_id="ed0a642f-2acf-c2da-232f-1b21300d5f29"
```


- Посмотрите ваши текущие секреты.
```shell
vault kv list app/
```


- Прочитайте секрет.
```shell
vault kv get data/mysecret
```
