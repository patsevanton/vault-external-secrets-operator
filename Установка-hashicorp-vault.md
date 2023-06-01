# Установка hashicorp vault
```shell
helm repo add bitnamicharts oci://registry-1.docker.io/bitnamicharts/vault
helm search repo bitnamicharts/vault
helm install vault bitnamicharts/vault -n vault --create-namespace
```

- Просмотр пользовательского интерфейса hashicorp vault
```bash 
kubectl port-forward vault-0 8200:8200 -n vault
```

- Инициализация и распечатывание хранилища
```
$kubectl get pods -l app.kubernetes.io/name=vault
NAME                                    READY   STATUS    RESTARTS   AGE
vault-0                                 0/1     Running   0          1m49s
```

- Инициализируйте один сервер хранилища с количеством общих ключей по умолчанию и пороговым значением ключа по умолчанию:
```
$kubectl exec -ti vault-0 -n vault -- vault operator init
Unseal Key 1: MBFSDepD9E6whREc6Dj+k3pMaKJ6cCnCUWcySJQymObb
Unseal Key 2: zQj4v22k9ixegS+94HJwmIaWLBL3nZHe1i+b/wHz25fr
Unseal Key 3: 7dbPPeeGGW3SmeBFFo04peCKkXFuuyKc8b2DuntA4VU5
Unseal Key 4: tLt+ME7Z7hYUATfWnuQdfCEgnKA2L173dptAwfmenCdf
Unseal Key 5: vYt9bxLr0+OzJ8m7c7cNMFj7nvdLljj0xWRbpLezFAI9

Initial Root Token: s.zJNwZlRrqISjyBHFMiEca6GF
```

- В выходных данных отображаются общие ключи и сгенерированный исходный корневой ключ. Распечатайте сервер hashicorp vault с общими ключами до тех пор, пока не будет достигнуто пороговое значение ключа:
```
## Unseal the first vault server until it reaches the key threshold
$ kubectl exec -ti vault-0 -n vault -- vault operator unseal # ... Unseal Key 1
$ kubectl exec -ti vault-0 -n vault -- vault operator unseal # ... Unseal Key 2
$ kubectl exec -ti vault-0 -n vault -- vault operator unseal # ... Unseal Key 3
```

- Войдите в систему из командной строки.
```
$ vault login 
Token (will be hidden): 
WARNING! The VAULT_TOKEN environment variable is set! The value of this
variable will take precedence; if this is unwanted please unset VAULT_TOKEN or
update its value accordingly.

Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                  Value
---                  -----
token                s.cdWzApasdkfjkasdqMHnuv
token_accessor       o03balkkjadskdfjd+uw4k
token_duration       ∞
token_renewable      false
token_policies       ["root"]
identity_policies    []
policies             ["root"]
```

- Мы будем использовать этот Token для подключения к hashicorp vault.

## APP ROLE
- Войдите в систему с помощью своего корневого токена
- Экспортируйте адрес hashicorp vault
    ```
    export VAULT_ADDR=http://127.0.0.1:8200
    ```
- Включите engine kv.
    ```
    vault secrets enable -version=2 -path=argocd kv
    ```
- Посмотрите ваши текущие секреты.
    ```
    vault secrets list
    ```
- Создавайте секрет.
    ```
    vault kv put argocd/mysecret foo=bar
    ```
- Включите approle.
    ```
    vault auth enable approle
    ```
- Создайте политику хранилища
    ```
    $vault policy write read-policy -<<EOF
    # Read-only permission on secrets stored at 'argocd/data'
    path "argocd/*" {
    capabilities = [ "read", "list" ]
    }
    EOF
    ```
- Создайте роль для approle
    ```
    vault write auth/approle/role/argocd token_policies="read-policy"
    ```
- Посмотрите политику
    ```
    vault read auth/approle/role/argocd
    ```
- Получите идентификатор роли approle (role_id)
    ```
    $vault read auth/approle/role/argocd/role-id

    Key     Value
    ---     -----
    role_id 675a50e7-cfe0-be76-e35f-49ec009731ea
    ```
- Получите секретный идентификатор (secret_id)
    ```
     $vault write -force auth/approle/role/argocd/secret-id

    Key                 Value
    ---                 -----
    secret_id           ed0a642f-2acf-c2da-232f-1b21300d5f29
    secret_id_accessor  a240a31f-270a-4765-64bd-94ba1f65703c
    ```

### Проверяем, работает ли approle или нет
- Войдите в систему, используя свою approle
    ```
    vault write auth/approle/login role_id="675a50e7-cfe0-be76-e35f-49ec009731ea" \
    secret_id="ed0a642f-2acf-c2da-232f-1b21300d5f29"
    ```
- Посмотрите ваши текущие секреты.
    ```
    vault kv list argocd/
    ```
- Прочитайте секрет.
    ```
    vault kv get test3/mysecret
    ```
