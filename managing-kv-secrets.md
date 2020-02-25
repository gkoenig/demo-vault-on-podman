## managing KV secrets

* environment  
  Ensure you set *VAULT_ADDR* and *VAULT_TOKEN* env properties, where the _VAULT\_TOKEN_ value can alternatively be put into file ```~/.vault-token```
  The vault address is the http endpoint of your vault server. In our demo scenario it is usually ```http://0.0.0.0:8200```, and to authenticate we will use the root token (!!! don't do this in production, create dedicated users first !!!). The root token you can find in the log output of the vault container start.  
  ```
  export VAULT_TOKEN="xxxxxxxxxxx"
  export VAULT_ADDR=http://0.0.0.0:8020
  ```

* enter vault container  
  replace _\<container-id\>_ by the one for your vault container (output of ps...)  
  ```sudo podman exec -it <container-id> /bin/sh```

#### enabling kv secret engine
  
  ```vault secrets enable kv```

#### adding a secret
- via cmdline cli
  - secret from a file  
```vault kv put kv/foofile @kv-sample-data.json```  
    where _data.json_ looks like:
    ```
    {   "data": 
        { 
            "Key1": "Value1", 
            "Key2": "Value2", 
            "Key3": "Value3" 
        } 
    }
    ```
  - secret provided directly
```vault kv put kv/foo mykey=foo-data```

- via REST


#### retrieving a secret

- listing a path  
  ```vault kv list kv```  

- via cmdline cli
    ```vault kv get kv/foo```    
    ```vault kv get kv/foofile``` # retrieve the key::map-of-values as added via put file above  
- via REST
    ```bash
    curl -X GET -H "X-Vault-Token:$VAULT_TOKEN" http://0.0.0.0:8200/v1/kv/foo
    ```

#### create/update a secret
- create a payload with your data/secrets
    ```
    {
        "options": {
            "cas": 0
        },
        "data": {
            "foo": "bar",
            "zip": "zap"
        }
    }

- send the request using above payload
    ```
    curl \
    --header "X-Vault-Token:$VAULT_TOKEN" \
    --request POST \
    --data @payload.json \
    https://0.0.0.0:8200/v1/kv/foo

#### deleting a secret
deleting is just a soft delete, data won't be destroyed and can be restored.

- via cmdline cli
    ```vault kv delete kv/foo```

- via REST
    ```
    curl \
    --header "X-Vault-Token:$VAULT_TOKEN" \
    --request DELETE \
    http://0.0.0.0:8200/v1/kv/data/foo 
    ```

#### un-deleting a secret
This just applies if you enabled **kv v2** secret engine !!  
- restoring versions from the specified payload file
    ```
    {
        "versions": [1, 2]
    }
    ```
- send the request using above payload
    ```
    curl \
    --header "X-Vault-Token:$VAULT_TOKEN" \
    --request POST \
    --data @payload.json \
    https://127.0.0.1:8200/v1/kv/undelete/foo

#### destroying a secret
Versioning just applies if you enabled **kv v2** secret engine !!  
- create a payload file
    ```
    {
      "versions": [1, 2]
    }
    ```
- send the request using the payload file
    ```
    curl \
    --header "X-Vault-Token:$VAULT_TOKEN" \
    --request POST \
    --data @payload.json \
    http://0.0.0.0:8200/v1/kv/destroy/foo