#!/bin/bash

mkdir -p "/home/$USER/.kube"
# Переходим в директорию master, где находится terragrunt конфигурация kubernetes master.
cd master
# Получаем cluster_id kubernetes.
export cluster_id=$(terragrunt output --raw cluster_id)
echo "$cluster_id"
cd ..
# Формируем файл конфигурации kubernetes
yc managed-kubernetes cluster get-credentials --id "$cluster_id" --external --force
