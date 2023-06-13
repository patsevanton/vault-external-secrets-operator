# Kubernetes секреты из Vault используя external-secrets-operator

## Введение
В этой статье будет описано как создать kubernetes секреты из Vault с помощью AppRole используя 
external-secrets-operator.

## Kubernetes кластер
Для начала создадим Kubernetes кластер (например, в Яндекс облаке с помощью Terragrunt).

Создание kubernetes кластера кратко описана в файле [create-k8s-by-terraform-in-yc.md]
(terragrunt-k8s/create-k8s-by-terraform-in-yc.md)

# Установка hashicorp vault. Если у вас hashicorp vault, то пропускаем раздел.
```shell
helm install vault oci://registry-1.docker.io/bitnamicharts/vault --version 0.2.1 -n vault --create-namespace
```

- Инициализация и распечатывание хранилища. Ждем когда vault-server-0 перейдет в состояние Running.
```shell
$ kubectl get pods --namespace "vault" -l app.kubernetes.io/instance=vault
NAME                              READY   STATUS    RESTARTS   AGE
vault-injector-6f8fb5dcff-9zhgm   1/1     Running   0          51s
vault-server-0                    0/1     Running   0          51s
```

- Инициализируйте один сервер хранилища с количеством общих ключей по умолчанию и пороговым значением ключа по умолчанию:
```shell
$ kubectl exec -ti vault-server-0 -n vault -- vault operator init
Unseal Key 1: ircItR+/QeLTsve4J3zqw9SPGhC5rDAuxZcz4jr8u4N/
Unseal Key 2: T/L9vkkm3+uo0H9XxADNAsr+YUCSPctnLC/011S79AVg
Unseal Key 3: gmSD+fb5A+4P7N3QLDtoLtzuiXnQuhE/Y4uB1RTlRU6h
Unseal Key 4: nMTwQQy81EPS8eS//kNicnvE5botOc5jyjHVuuqGkva7
Unseal Key 5: 1roVdnVqvZnHroOijEZFMiueeGE1WF2WWRUWJ4MWCjyF

Initial Root Token: hvs.bY28dn6cKyp6JCvPLTV3Eufb
```

- В выходных данных отображаются общие ключи и сгенерированный исходный корневой ключ. Распечатайте сервер hashicorp vault с общими ключами до тех пор, пока не будет достигнуто пороговое значение ключа:
```shell
kubectl exec -ti vault-server-0 -n vault -- vault operator unseal # ... Unseal Key 1
kubectl exec -ti vault-server-0 -n vault -- vault operator unseal # ... Unseal Key 2
kubectl exec -ti vault-server-0 -n vault -- vault operator unseal # ... Unseal Key 3
```

- В ОТДЕЛЬНОМ терминале пробросьте порт 8200 от hashicorp vault
```shell 
kubectl port-forward vault-server-0 8200:8200 -n vault
```

- Экспортируйте адрес hashicorp vault
```shell
export VAULT_ADDR=http://127.0.0.1:8200
```

Вы можете либо настроить AppRole в Vault из CLI либо через terraform код.

Настроим AppRole Vault через terraform.

Создайте `setting-approle-vault.tf` со следующим содержимым:
```hcl
# Включение engine kv из CLI.
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

# Создание политики для чтения по пути secret/data/postgres
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
```

Пример `setting-approle-vault.tf` есть в директории vault-resource.

Экспортируем ваш токен (в данном случае root токен)
```shell
export VAULT_TOKEN=hvs.bY28dn6cKyp6JCvPLTV3Eufb
```

Применим конфигурацию terraform.
```shell
terraform init
terraform apply
```

- Создайте секрет из CLI. Здесь указываем `secret/postgres` без `data`.
```shell
$ vault kv put secret/postgres POSTGRES_USER=admin POSTGRES_PASSWORD=123456
==== Secret Path ====
secret/data/postgres

======= Metadata =======
Key                Value
---                -----
created_time       2023-06-13T04:02:53.164920751Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1
```

Обратим внимание что Secret Path имеет значение `secret/data/postgres`.
Именно этот Secret Path прописываем в external-secret.yaml.

Либо создайте Vault секрет через UI как показано на скриншоте:
![Create-vault-secret-from-cli.png](vault-resource/Create-vault-secret-from-cli.png)

Выведим на экран терминала role-id и secret-id и запоминаем их значение.
```shell
terraform output role_id
terraform output secret_id
```

Если вам интересно настроить AppRole в Vault из CLI, то настройка описано в отдельном файле 
[create-approle-vault-cli.md](vault-resource/create-approle-vault-cli.md)


Добавляем helm репо External Secrets Operator
```shell
helm repo add external-secrets https://charts.external-secrets.io
```

Устанавливаем External Secrets Operator
```shell
helm install external-secrets \
external-secrets/external-secrets \
    --wait \
    -n external-secrets \
    --create-namespace \
    --version 0.8.3 \
    --set installCRDs=true
```

Настройка external-secrets.
 - Указываем `role_id` в файле `external-secrets/secret-store.yaml` в поле `roleId`.
 - Указываем `secret_id` в файле `external-secrets/vault-secret.yaml` в поле `secret-id`.
Файлы конфигурации в директории external-secrets подробно документированы.


Применяем yaml из директории external-secrets
```shell
kubectl apply -f external-secrets/vault-secret.yaml
kubectl apply -f external-secrets/secret-store.yaml
kubectl apply -f external-secrets/external-secret.yaml
```

Дебаг:
ClusterSecretStore c названием vault-backend должен иметь CAPABILITIES - ReadWrite.
```shell
$ kubectl get ClusterSecretStore vault-backend
NAME            AGE     STATUS   CAPABILITIES   READY
vault-backend   3m19s   Valid    ReadWrite      True
```

Если ExternalSecret имеет статус SecretSyncedError, то смотрим describe.
```shell
$ kubectl get ExternalSecret -n external-secrets external-secret
NAMESPACE          NAME              STORE           REFRESH INTERVAL   STATUS              READY
external-secrets   external-secret   vault-backend   5s                 SecretSyncedError   False
```

Смотрим describe ExternalSecret.
```shell
kubectl describe ExternalSecret -n external-secrets external-secret
```
Если видим ошибку `permission denied`, значит неправильно настроли пути.
```shell
Code: 403. Errors:

* 1 error occurred:
  * permission denied
```

Тестирование AppRole используя Vault cli.
Входим в vault используя `role_id` и `secret_id`
```shell
$ vault write auth/approle/login role_id="" secret_id=""
Key                     Value
---                     -----
token                   hvs.CAESILZuXjEGHKTTUD7WjNKDXijGSDLrWTWvE6xzB6O2BXrxGh4KHGh2cy5tZEZhNFVIODdhUktjRDViQVFaUmswc20
token_accessor          tNDR6kn0R3rM1idryFOkSBmi
token_duration          768h
token_renewable         true
token_policies          ["default" "read-policy"]
identity_policies       []
policies                ["default" "read-policy"]
token_meta_role_name    data
```

Получаем список секретов
```shell
vault kv list secret
```

Прочитаем секрет
```shell
vault kv get secret/postgres
```

Если получаем ошибку, то меняем политику на такую и проверяем правильность путей (path)
```shell
resource "vault_policy" "secret-read-policy" {
  name = "read-policy"

  policy = <<EOT
path "*" {
  capabilities = ["read", "list"]
}
EOT
}
```

# Links:
 - https://github.com/fvoges/terraform-vault-basic-workflow
 - https://github.com/tiwarisanjay/external-secrets-operator
 - https://github.com/tiwarisanjay/argocd-everything/blob/main/argocd-ha-vault-sso/README.md
 - https://artifacthub.io/packages/helm/bitnami/vault
 - https://gengwg.medium.com/setting-up-flux-v2-with-kind-cluster-and-github-on-your-laptop-56e28b0a8120
 - https://github.com/hashicorp/terraform-provider-vault/blob/main/website/docs/r/mount.html.md
 - https://earthly.dev/blog/eso-with-hashicorp-vault/
