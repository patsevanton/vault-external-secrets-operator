# Start a Vault server in development mode.
```shell
vault server -dev
```

# Copy root token from output `vault server -dev`

# Export root token
export VAULT_TOKEN=hvs.UCNpuNfhUgYH2dhPOcLUHbiu

# Export vault address
export VAULT_ADDR=http://127.0.0.1:8200

# Apply to terraform configuration
terraform apply
