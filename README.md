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

Запускаем применение всех terraform модулей в текущем каталоге:
```shell
terragrunt run-all apply
```

Сформируем файл конфигурации kubernetes.
Подробности и комментарии находятся внутри скрипта.
```shell
./change_context.sh
```

## FluxCD
Устанавливаем последний релиз FluxCD до версии 2.0.0
https://github.com/fluxcd/flux2/releases/tag/v0.41.2

Получаем личный токен доступа к [Github](https://github.com/settings/tokens). Проверьте все разрешения в разделе репозиторий.

Export them:
```shell
export GITHUB_TOKEN=<your-token>
export GITHUB_USER=patsevanton # <your-github-username>
```


Запускаем bootstrap FluxCD
```shell
flux bootstrap github --owner=$GITHUB_USER --repository=flux-vault-external-secrets-operator --branch=main 
--path=./gitops --personal
```