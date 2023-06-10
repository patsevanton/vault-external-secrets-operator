Структура каталогов с terraform модулями для terragrunt описана в статье [Управление инфраструктурой с
помощью terragrunt (terraform) и gitlab ci](https://habr.com/ru/articles/719994/).

Переходим в каталог terragrunt-k8s относительно корня проекта
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
