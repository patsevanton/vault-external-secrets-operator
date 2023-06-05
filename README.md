# Kubernetes секреты из Vault используя external-secrets-operator и FluxCD

## Введение
В этой статье будет описано как создать kubernetes секреты из Vault с помощью AppRole используя 
external-secrets-operator. Также будет использован Terragrunt.

## Kubernetes кластер
Для начала создадим Kubernetes кластер (например, в Яндекс облаке) с помощью Terragrunt.

Структура каталогов с terraform модулями для terragrunt описана в статье [Управление инфраструктурой с 
помощью terragrunt (terraform) и gitlab ci](https://habr.com/ru/articles/719994/).

Переходим в каталог terragrunt-k8s
```shell
cd terragrunt-k8s
```

Экспортируем yandex cloud токен.
```shell
export YC_TOKEN="ваш yandex cloud токен"
```

Запускаем применение всех terraform модулей в текущем каталоге:
```shell
terragrunt run-all apply
```

Сформируем файл конфигурации kubernetes.
Подробности и комментарии находятся внутри скрипта.
```shell
./change_context.sh
```

Выходим из каталога terragrunt-k8s
```shell
cd ..
```


# Установка hashicorp vault
```shell
helm install vault oci://registry-1.docker.io/bitnamicharts/vault --version 0.2.1 -n vault --create-namespace
```

- Инициализация и распечатывание хранилища
```shell
$kubectl get pods --namespace "vault" -l app.kubernetes.io/instance=vault
NAME                              READY   STATUS    RESTARTS   AGE
vault-injector-6f8fb5dcff-bbl2s   0/1     Running   0          14s
vault-server-0                    0/1     Pending   0          7s
```

- Инициализируйте один сервер хранилища с количеством общих ключей по умолчанию и пороговым значением ключа по умолчанию:
```shell
$kubectl exec -ti vault-server-0 -n vault -- vault operator init
Unseal Key 1: YT1QnYq+VXSM5pnwz7MS3qYuMACMHTrBUUFpLNbmQ6Ud
Unseal Key 2: ZigBlTiKhnFNecJFFNrI0eR2s87rnnqLJ+plcth/V1Yr
Unseal Key 3: Y+TB1Jv9UjpWYLY3dQZBGo29vQ2rPcN2Q7NG/VrgFoAf
Unseal Key 4: MSA7BdZ5/vm4pTEjrzhCxpUpQQM1fmWSAfpuxVMAWoaf
Unseal Key 5: E7j1KuXeoj2rh3izGrILyk0nHEWnNlBAHcdUpkeV9Z2L

Initial Root Token: hvs.CbxNhv9GcnjcUbAFCrQHOKti
```

- В выходных данных отображаются общие ключи и сгенерированный исходный корневой ключ. Распечатайте сервер hashicorp vault с общими ключами до тех пор, пока не будет достигнуто пороговое значение ключа:
```shell
$ kubectl exec -ti vault-server-0 -n vault -- vault operator unseal # ... Unseal Key 1
$ kubectl exec -ti vault-server-0 -n vault -- vault operator unseal # ... Unseal Key 2
$ kubectl exec -ti vault-server-0 -n vault -- vault operator unseal # ... Unseal Key 3
```

- В отдельном терминале пробросьте порт 8200 от hashicorp vault
```shell 
kubectl port-forward vault-server-0 8200:8200 -n vault
```

- Экспортируйте адрес hashicorp vault
```shell
export VAULT_ADDR=http://127.0.0.1:8200
```

Вы можете либо настроить AppRole в Vault из CLI либо через terraform код.

Настроим AppRole Vault через terraform.
Переходим в директорию с файлом `setting-approle-vault.tf`
```shell
cd vault-resource
```

Экспортируем ваш токен (в данном случае root токен)
```shell
export VAULT_TOKEN=hvs.CbxNhv9GcnjcUbAFCrQHOKti
```

Применим конфигурацию terraform.
```shell
terraform apply
```

Выведите на экран терминала role-id и secret-id
```shell
terraform output role_id
terraform output secret_id
```

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
resource "vault_mount" "kvv2-app" {
  path        = "app"
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
vault kv put app/mysecret foo=bar
```

Terraform код создания секрета. Но лучше секреты в коде не держать.
```hcl
resource "vault_kv_secret_v2" "example" {
  mount = vault_mount.kvv2-app.path
  name  = "secret"
  data_json = jsonencode(
    {
      foo = "bar"
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
# Read-only permission on secrets stored at 'app/data'
path "app/*" {
capabilities = [ "read", "list" ]
}
EOF
```

Terraform код создания политики для чтения по пути app/*
```hcl
resource "vault_policy" "read-policy" {
  name = "read-policy"

  policy = <<EOT
path "app/*" {
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
resource "vault_approle_auth_backend_role" "app" {
  backend        = vault_auth_backend.approle.path
  role_name      = "app"
  token_policies = ["read-policy"]
}
```


- Посмотрите политику
```shell
vault read auth/approle/role/app
```


- Получите идентификатор роли approle (role_id)
```shell
$vault read auth/approle/role/app/role-id

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
  role_name = vault_approle_auth_backend_role.app.role_name
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
vault kv get test3/mysecret
```



Устанавливаем External Secrets Operator
```shell
helm repo add external-secrets https://charts.external-secrets.io

helm install external-secrets \
external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
    --version 0.8.3 \
    --set installCRDs=true
```


# Links:
https://github.com/fvoges/terraform-vault-basic-workflow
https://github.com/tiwarisanjay/external-secrets-operator
https://github.com/tiwarisanjay/argocd-everything/blob/main/argocd-ha-vault-sso/README.md
https://artifacthub.io/packages/helm/bitnami/vault
https://gengwg.medium.com/setting-up-flux-v2-with-kind-cluster-and-github-on-your-laptop-56e28b0a8120
https://github.com/hashicorp/terraform-provider-vault/blob/main/website/docs/r/mount.html.md

