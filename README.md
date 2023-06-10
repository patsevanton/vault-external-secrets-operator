# Kubernetes секреты из Vault используя external-secrets-operator и FluxCD

## Введение
В этой статье будет описано как создать kubernetes секреты из Vault с помощью AppRole используя 
external-secrets-operator. Также будет использован Terragrunt.

## Kubernetes кластер
Для начала создадим Kubernetes кластер (например, в Яндекс облаке с помощью Terragrunt.

Создание kubernetes кластера примерно описана в файле [create-k8s-by-terraform-in-yc.md](terragrunt-k8s/create-k8s-by-terraform-in-yc.md)

# Установка hashicorp vault
```shell
helm install vault oci://registry-1.docker.io/bitnamicharts/vault --version 0.2.1 -n vault --create-namespace
```

- Инициализация и распечатывание хранилища
```shell
$ kubectl get pods --namespace "vault" -l app.kubernetes.io/instance=vault
NAME                              READY   STATUS    RESTARTS   AGE
vault-injector-6f8fb5dcff-bbl2s   0/1     Running   0          14s
vault-server-0                    0/1     Pending   0          7s
```

- Инициализируйте один сервер хранилища с количеством общих ключей по умолчанию и пороговым значением ключа по умолчанию:
```shell
$ kubectl exec -ti vault-server-0 -n vault -- vault operator init
Unseal Key 1: +BUVjcZMuUFR+EtIwjt4H57VFRtbdkj7LotbFF33ADV7
Unseal Key 2: OoicbcCIIRl+beqRMuDfmnS0XF//hWC+5rNDEDVq6R5R
Unseal Key 3: S6HYS3UYcRzptqrRtBL+eazYxeBohGv/B+0Ku2utSxi1
Unseal Key 4: El0XebwVbFcZckB20j6tQGWhjcRTiOmVgzGnxsGa3i6X
Unseal Key 5: 0AdRUThHnqTiwVz64dEWI3gaqSTwx18NwnM7I2NBBJKF

Initial Root Token: hvs.NkWkXPiUFsy0RM69lZokLUu8
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
export VAULT_TOKEN=hvs.NkWkXPiUFsy0RM69lZokLUu8
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

Настройка AppRole в Vault из CLI описана в отдельном файле [create-approle-vault-cli.md](vault-resource/create-approle-vault-cli.md)


Добавляем helm репо External Secrets Operator
```shell
helm repo add external-secrets https://charts.external-secrets.io
```

Устанавливаем External Secrets Operator
```shell
helm install external-secrets \
external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
    --version 0.8.3 \
    --set installCRDs=true
```

Применяем yaml из директории external-secrets
```shell
kubectl apply -f external-secrets
```

# Links:
 - https://github.com/fvoges/terraform-vault-basic-workflow
 - https://github.com/tiwarisanjay/external-secrets-operator
 - https://github.com/tiwarisanjay/argocd-everything/blob/main/argocd-ha-vault-sso/README.md
 - https://artifacthub.io/packages/helm/bitnami/vault
 - https://gengwg.medium.com/setting-up-flux-v2-with-kind-cluster-and-github-on-your-laptop-56e28b0a8120
 - https://github.com/hashicorp/terraform-provider-vault/blob/main/website/docs/r/mount.html.md
 - https://earthly.dev/blog/eso-with-hashicorp-vault/
