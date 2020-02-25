# Starting Vault via podman pod

### create new pod , starting vault 

- Start in foreground , **DEV** mode:  

```bash
sudo podman run --cap-add IPC_LOCK --rm docker.io/library/vault -p 8200:8200 --pod new:vault
```

- If you want to run Vault in **server mode**, use:
  - create vaultserver.hcl in directory ./vaultconfig  
  ```mkdir ./vaultconfig && vi ./vaultconfig/vaultserver.hcl```

    with content of _vaultserver.hcl_ :

    ```bash
    listener "tcp" {
        address = "0.0.0.0:8200"
        tls_disable = 1
    }
    storage "file" {
        path = "/vault/file"
    }
    disable_mlock = true
    api_addr = "http://0.0.0.0:8200"
    ui=true
    ```

  - start Vault in server mode providing config from above
  
    ```bash
    sudo podman run -v ./vaultconfig:/vault/config --security-opt label=disable --cap-add=IPC_LOCK  -p 8200:8200 --pod new:vault docker.io/library/vault server
    ```

  -enter the vault container  
    ```sudo podman exec -it xxxxxxx /bin/sh```
    replace xxxxxxx by the ID of your vault container
  -initialize vault server
    ```vault operator init -key-shares=1 -key-threshold=1 -address=http://0.0.0.0:8200```
    we will just use 1 unseal key for this demo purposes, in real world setups you will set property _-key-shares_ to at least 3, or 5.
    **!!!** copy the _Initial Root Token_ and your _Unseal Key_ from the output of the operator init command.....and export env property for the token.  
    ```export VAULT_TOKEN="<<your-vault-token>>"```  
    ```export VAULT_ADDR="http://0.0.0.0:8200"```

  -unseal vault server  
    ```vault operator unseal -address=http://0.0.0.0:8200``` , followed by providing the unseal key you recorded in the previous step. This should give you a similar output to:  
    ```
    ># vault operator unseal
    Unseal Key (will be hidden):
    Key             Value
    ---             -----
    Seal Type       shamir
    Initialized     true
    Sealed          false
    Total Shares    1
    Threshold       1
    Version         1.2.3
    Cluster Name    vault-cluster-02a47cee
    Cluster ID      b9c1b5dc-d1e7-9aad-61e5-295978be65e1
    HA Enabled      false
    ```

    check status via: ```vault status```