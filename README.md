# Kubernetes секреты из Vault используя external-secrets-operator и FluxCD

## Введение
В этой статье будет описано как создать kubernetes секреты из Vault с помощью AppRole используя 
external-secrets-operator. Также будут использованы Terragrunt и FluxCD.

## Kubernetes кластер
Для начала создадим Kubernetes кластер (например, в Яндекс облаке) с помощью Terragrunt.

Структура каталогов с terraform модулями для terragrunt описана в статье [Управление инфраструктурой с 
помощью terragrunt (terraform) и gitlab ci](https://habr.com/ru/articles/719994/).

Переходим в каталог terraform-k8s-terragrunt-vault-external-secret
```shell
cd terraform-k8s-terragrunt-vault-external-secret
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

Выходим из каталога terraform-k8s-terragrunt-vault-external-secret
```shell
cd ..
```

## FluxCD
Устанавливаем последний релиз FluxCD до версии 2.0.0, например 0.41.2.
https://github.com/fluxcd/flux2/releases/tag/v0.41.2

Получаем личный токен доступа к [Github](https://github.com/settings/tokens). Проверьте все разрешения в разделе репозиторий.

Export them:
```shell
export GITHUB_TOKEN=<your-token>
export GITHUB_USER=patsevanton # <your-github-username>
```

Запускаем bootstrap FluxCD для репозитория. У вас будет другой параметр `--repository`
```shell
flux bootstrap github --owner=$GITHUB_USER --repository=flux-vault-external-secrets-operator \
--branch=main --path=./gitops --personal
```

Проверяем что все поды запущены
```shell
kubectl get pods --namespace "flux-system"
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
Unseal Key 1: HnMRsR4t9nJEm0DWBGNxqpKwC6bDS0uw5wZ8f6+9yt6n
Unseal Key 2: dr91I4xjQap+HCPOnjAwMXhYekGd/oNiBKWTrVKfrBXb
Unseal Key 3: YPqIeVzIgoDvHXDeA9Jc3iLJDqYcnEsPOWarQWWWuySV
Unseal Key 4: pk5n6C/VQHxmK9D4N8Wc6Tjh7UMdKZtILhVvBXXEDwir
Unseal Key 5: n9CVHap91BsjSEJhq3z1RXjkfUCU5Y8Pw8wQrzfbqfhb

Initial Root Token: hvs.AYVtnoS0RVvXusZgOjOJP1Yt
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

- Войдите в систему из командной строки.
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

## APP ROLE
- Войдите в систему с помощью своего корневого токена

- Включите engine kv из CLI.
```shell
vault secrets enable -version=2 -path=app kv
```

Или включите engine kv c помощью terraform кода
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

Или создайте секрет c помощью terraform кода
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


- Создайте политику хранилища
```shell
$vault policy write read-policy -<<EOF
# Read-only permission on secrets stored at 'app/data'
path "app/*" {
capabilities = [ "read", "list" ]
}
EOF
```
- Создайте роль для approle
```shell
vault write auth/approle/role/app token_policies="read-policy"
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
- Получите секретный идентификатор (secret_id)
```shell
 $vault write -force auth/approle/role/app/secret-id

Key                 Value
---                 -----
secret_id           ed0a642f-2acf-c2da-232f-1b21300d5f29
secret_id_accessor  a240a31f-270a-4765-64bd-94ba1f65703c
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



# Links:
https://github.com/fvoges/terraform-vault-basic-workflow
https://github.com/tiwarisanjay/external-secrets-operator
https://github.com/tiwarisanjay/argocd-everything/blob/main/argocd-ha-vault-sso/README.md
https://artifacthub.io/packages/helm/bitnami/vault
https://fluxcd.io/flux/cheatsheets/oci-artifacts/
https://fluxcd.io/flux/cmd/flux_bootstrap_github/
https://gengwg.medium.com/setting-up-flux-v2-with-kind-cluster-and-github-on-your-laptop-56e28b0a8120
https://github.com/hashicorp/terraform-provider-vault/blob/main/website/docs/r/mount.html.md

