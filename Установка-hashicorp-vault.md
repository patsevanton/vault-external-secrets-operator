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
Unseal Key 1: 3hfzlgCDXNLzNMryUiUf79ZWKAkwEjANp/CVwtUxeORx
Unseal Key 2: ii9jcnE7NWalvL0+KfIfU7j4U7l1kGuWo/E8rlz8A1BK
Unseal Key 3: uAr8fUedlkbYCUob1FGrDVBCmPQ0v+pplvkfLznir6qV
Unseal Key 4: copw9ipbbWrxFQvob4WEOl9TVctwxh8m1nj5p2eGp4y4
Unseal Key 5: GyPKNmuVwrK4qIP79hm6c2DXMBBra1SnN+MU7Zzg9nS+

Initial Root Token: hvs.pPEDt7A7JcpqTXYDI7Esk8iW
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

- Включите engine kv.
```shell
vault secrets enable -version=2 -path=argocd kv
```
- Посмотрите ваши текущие секреты.
```shell
vault secrets list
```
- Создавайте секрет.
```shell
vault kv put argocd/mysecret foo=bar
```
- Включите approle.
```shell
vault auth enable approle
```
- Создайте политику хранилища
```shell
$vault policy write read-policy -<<EOF
# Read-only permission on secrets stored at 'argocd/data'
path "argocd/*" {
capabilities = [ "read", "list" ]
}
EOF
```
- Создайте роль для approle
```shell
vault write auth/approle/role/argocd token_policies="read-policy"
```
- Посмотрите политику
```shell
vault read auth/approle/role/argocd
```
- Получите идентификатор роли approle (role_id)
```shell
$vault read auth/approle/role/argocd/role-id

Key     Value
---     -----
role_id 675a50e7-cfe0-be76-e35f-49ec009731ea
```
- Получите секретный идентификатор (secret_id)
```shell
 $vault write -force auth/approle/role/argocd/secret-id

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
vault kv list argocd/
```
- Прочитайте секрет.
```shell
vault kv get test3/mysecret
```
