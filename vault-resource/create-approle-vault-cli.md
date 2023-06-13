
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
vault secrets enable -version=2 -path=secret kv
```

Terraform код включения engine kv.
```hcl
resource "vault_mount" "kvv2-secret" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}
```

- Создайте секрет из CLI.
```shell
vault kv put secret/postgres POSTGRES_USER=admin POSTGRES_PASSWORD=123456
==== Secret Path ====
secret/data/postgres

======= Metadata =======
Key                Value
---                -----
created_time       2023-06-13T03:27:59.492399614Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1
```

Обратим внимание на Secret Path: `secret/data/postgres`

Terraform код создания секрета. Но лучше секреты в коде не держать.
```hcl
resource "vault_kv_secret_v2" "example" {
  mount = vault_mount.kvv2-secret.path
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
cubbyhole/    cubbyhole    cubbyhole_22e57e30    per-token private secret storage
identity/     identity     identity_10e6aaac     identity store
secret/       kv           kv_6be1e2f8           n/a
sys/          system       system_0ec7ea71       system endpoints used for control, policy and debugging
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
path "secret/data/postgres" {
capabilities = [ "read", "list" ]
}
EOF
```

Terraform код создания политики для чтения по пути app/*
```hcl
resource "vault_policy" "read-policy" {
  name = "read-policy"

  policy = <<EOT
path "secret/data/postgres" {
  capabilities = ["read", "list"]
}
EOT
}
```

- Создайте роль для approle.
```shell
vault write auth/approle/role/secret token_policies="read-policy"
```

Terraform код создания роли для approle.
```hcl
resource "vault_approle_auth_backend_role" "secret" {
  backend        = vault_auth_backend.approle.path
  role_name      = "secret"
  token_policies = ["read-policy"]
}
```


- Посмотрите политику
```shell
vault read auth/approle/role/secret
```


- Получите идентификатор роли approle (role_id)
```shell
$ vault read auth/approle/role/secret/role-id
Key        Value
---        -----
role_id    9288079d-5f31-46d4-7e43-2fb78ef42f87
```


- Создайте и получите секретный идентификатор (secret_id)
```shell
$ vault write -force auth/approle/role/secret/secret-id
Key                   Value
---                   -----
secret_id             dc86bb6f-5b22-b3cf-ae24-686222af4668
secret_id_accessor    9d68da4e-c72a-791c-8bc8-2a972e032710
secret_id_num_uses    0
secret_id_ttl         0s
```

Terraform код создания секретного идентификатора (secret_id)
```hcl
resource "vault_approle_auth_backend_role_secret_id" "id" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.secret.role_name
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
$ vault write auth/approle/login role_id="" \
secret_id=""
Key                     Value
---                     -----
token                   hvs.CAESID5qAJ-0GDBxmTXiuFvvIH4_hZ-cTHPV_bDbR7FwbAcbGh4KHGh2cy5zcktmemxrRldIS08yWllpWVFBVFRKN0c
token_accessor          nRg8XUUPoWJaX2Mn433ee8ko
token_duration          768h
token_renewable         true
token_policies          ["default" "read-policy"]
identity_policies       []
policies                ["default" "read-policy"]
token_meta_role_name    secret

```


- Посмотрите ваши текущие секреты.
```shell
vault kv list secret
```


- Прочитайте секрет.
```shell
vault kv get secret/postgres
```
