# Hashicorp Vault on Podman

[Hashicorp Vault](https://www.vaultproject.io/)  
[Podman](https://podman.io/getting-started/)

## container setup
Vault in DEV mode just stores everything in memory, means after shutting down, everything is gone. Please keep this in mind!

### creating containers & pods
- create a container
  sample httpd server:  
  ```bash
  podman run -dt -p 8080:8080/tcp -e HTTPD_VAR_RUN=/var/run/httpd -e HTTPD_MAIN_CONF_D_PATH=/etc/httpd/conf.d \
                  -e HTTPD_MAIN_CONF_PATH=/etc/httpd/conf \
                  -e HTTPD_CONTAINER_SCRIPTS_PATH=/usr/share/container-scripts/httpd/ \
                  registry.fedoraproject.org/f29/httpd /usr/bin/run-httpd
  ```

- create an empty pod

- create a pod including a container running an app
```bash
sudo podman run --cap-add IPC_LOCK --rm docker.io/library/vault -p 8200:8200 --pod new:vault
```

### list
- list containers:  
```sudo podman ps```
- list _all_ containers:  
```sudo podman ps -a```
- list pods and included containers:  
```sudo podman ps -a --pod```
check the output for your container running _vault_ and pick its container-id

### check
- inspect container
```sudo podman inspect <<containerid>>```
- get logs
```sudo podman logs <<containerid>>```

### managing pods
- add a container to a pod:  
``` ```
- stop a container in a pod:  
```sudo podman stop <<container-id>>```
- stop a pod:  
```sudo podman pod stop <<pod-id>>```
- start a pod again:
```sudo podman pod start <<pod-id>>```
- delete a pod:
```sudo podman pod rm <<pod-id>>```


### create new pod , starting vault 

* Start in foreground , **DEV** mode:  

```bash
sudo podman run --cap-add IPC_LOCK --rm docker.io/library/vault -p 8200:8200 --pod new:vault
```

* If you want to run Vault in **server mode**, use:
  * create vaultserver.hcl in directory ./vaultconfig  
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

  * start Vault in server mode providing config from above
  
    ```bash
    sudo podman run -v ./vaultconfig:/vault/config --security-opt label=disable --cap-add=IPC_LOCK  -p 8200:8200 --pod new:vault docker.io/library/vault server
    ```

  * enter the vault container  
    ```sudo podman exec -it xxxxxxx /bin/sh```
    replace xxxxxxx by the ID of your vault container
  * initialize vault server
    ```vault operator init -key-shares=1 -key-threshold=1 -address=http://0.0.0.0:8200```
    we will just use 1 unseal key for this demo purposes, in real world setups you will set property _-key-shares_ to at least 3, or 5.
    **!!!** copy the _Initial Root Token_ and your _Unseal Key_ from the output of the operator init command.....and export env property for the token.  
    ```export VAULT_TOKEN="<<your-vault-token>>"```  
    ```export VAULT_ADDR="http://0.0.0.0:8200"```

  * unseal vault server  
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


# using Vault

## secrets

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

### KV secrets
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

### PKI management
Demo is doing a 2-level CA chain, means main CA is created outside of Vault, but used to sign the csr of Vault's ca.  
First step is to create the **main CA** via _cfssl_ on your local box:  

```bash
cfssl genkey -initca ./cfssl-ca-config.json | cfssljson -bare ./root-cert
```

Ensure that you set the env properties:

```export VAULT_TOKEN="<<your-vault-token>>"```  
```export VAULT_ADDR="http://0.0.0.0:8200"```  
```export VAULT_DOMAIN="my.example.com"```  

- enable PKI secret engine and _mount_ it under "pki"
  - cmdline  
  ```vault secrets enable pki```
  - REST
  ```bash
  curl --silent --header "X-Vault-Token: "$VAULT_TOKEN \
    --request POST --data '{"type":"pki"}' \
    $VAULT_ADDR/v1/sys/mounts/pki
  ```

- configure the CA
  - set max_lease_ttl
  - set common_name and ttl
  - set issuing certificates domain and crl_distribution_points 
  - store the csr in file /vault/config/issuing-ca.csr #reason for this folder is, because it is shared with the host to exchange the files 
  
```bash
curl --silent --header "X-Vault-Token: "$VAULT_TOKEN \
  --request POST --data '{"max_lease_ttl":"87600h"}' \
  $VAULT_ADDR/v1/sys/mounts/pki/tune || true
curl --silent --header "X-Vault-Token: "$VAULT_TOKEN \
  --request POST --data '{"common_name":"'$VAULT_DOMAIN'","ttl":"26280h"}' \
  $VAULT_ADDR/v1/pki/intermediate/generate/internal \
  | jq -r '.data.csr' > /vault/config/issuing-ca.csr
curl --silent --header "X-Vault-Token: "$VAULT_TOKEN \
  --request POST --data '{"issuing_certificates":"http://'$VAULT_DOMAIN':8200/v1/pki/ca","crl_distribution_points":"http://'$VAULT_DOMAIN':8200/v1/pki/crl"}' \
  $VAULT_ADDR/v1/pki/config/urls || true
```

- sign the issuing CA request
  - prepare a json for signing the csr, save this filt to _signing-config.json_  
  
    ```bash
    {
        "signing": {
            "default": {
                "expiry": "43800h",
                "usages": ["signing", "key encipherment", "cert sign", "crl sign"],
                "ca_constraint": {"is_ca": true}
            }
        }
    }
    ```

  - actually sign the csr
    **this is being executed on your local box, where you created the cfssl CA, NOT the vault one**  

    ```export VAULT_DOMAIN="my.example.com"```  
    **ensure you set the VAULT_DOMAIN to the same value as within the Vault box**
    
    ```bash
    cfssl sign -ca ./root-cert.pem \
    -ca-key ./root-cert-key.pem \
    -hostname $VAULT_DOMAIN -config ./signing-config.json \
    ./vaultconfig/issuing-ca.csr | sed -E 's/cert/certificate/' \
    > ./vaultconfig/issuing.pem
    ```

  - upload signed cert to Vault
    ** run this from within vault container, using issuing.pem from shared folder **

    ```bash
    curl --silent --header "X-Vault-Token: "$VAULT_TOKEN \
      --request POST --data @/vault/config/issuing.pem \
      $VAULT_ADDR/v1/pki/intermediate/set-signed
    ```

  - Next, you need to create a role to be able to generate certificates for your domain

    ```export VAULT_ALLOWED_DOMAIN="democompany.com"```

    ```bash
    curl --silent --header "X-Vault-Token: "$VAULT_TOKEN \
      --request POST --data '{"allowed_domains":"'$VAULT_ALLOWED_DOMAIN'","allow_subdomains":true,"max_ttl":"720h"}' \
      $VAULT_ADDR/v1/pki/roles/generate-cert-role || true
    ```

  - finally generate a certificate

    ```bash
    DOMAIN_NAME="mysql1.democompany.com"

    curl --silent --header "X-Vault-Token: "$VAULT_TOKEN \
      --request POST --data '{"common_name":"'$DOMAIN_NAME'"}' \
      $VAULT_ADDR/v1/pki/issue/generate-cert-role
    ```

    This step will do the following:  

    - private key
    - public key
    - certificate chain / ca_chain comprising of the public key of issuing CA. By default, it will include only 1  certificate same as issuing_ca. When uploading certificate data to the application, you will need to add certificate a public key of root CA server to the certificate chain, so the applications will trust the certificate.

    Now you need to extract private_key, ca_chain (and add public cert of root certificate to it) and, certificate.
    - certificate
    - private_key
    - ca_chain (!! add the public key of the main CA, the one you created with _cfssl_ !!) 

## auth methods
Vault offers several methods for authentication. So far we used _token based_ auth , with the root token.  
To use another method (user/passwd, AWS/Azure/GCP, Github, LDAP, ....) you have to enable the corresponding method first.

### e.g. authentication via Github
- enable auth method 
  ```vault auth enable github```
- configure the method, if applicable
  ```vault write auth/github/config organization=Scigility```  
- map users/teams of that organization to policies
  ```vault write auth/github/map/teams/dev value=dev-policy```  
  In this example, when members of the team "dev" in the organization "Scigility" authenticate to Vault using a GitHub personal access token, they will be given a token with the "dev-policy" policy attached.
  The same can also be done for single users, by talking to the _users_ endpoint  
  ```vault write auth/github/map/users/gerd value=gerd-policy```
- check the auth backend
  ```vault read auth/github/config```

## policies
With policies you can limit access to certain "paths" within vault in ACL style.  
It is best practice to first create an _admin_ policy, because you should never work actively with the _root_ token (same principal as e.g. in AWS to never use the root account).  

### create policy

*admin* policy must be able to:
- Enable and manage auth methods broadly across Vault
- Enable and manage the key/value secrets engine at secret/ path
- Create and manage ACL policies broadly across Vault
- Read system health check
  
Create the policy by using the _admin-policy.hcl_ script, which defines all the above mentioned actions:  
```vault policy write admin admin-policy.hcl```

Let's create a policy _gerd-policy_ which we already assigned to the singleuser _gerd_ (of github auth backend):  
  ```vault policy write gerd-policy gerd.hcl```

### check policies
- list
  ```vault policy list```  
  or, by REST  
  
  ```bash
  curl --request LIST --header "X-Vault-Token: <TOKEN>" \
       http://127.0.0.1:8200/v1/sys/policies/acl | jq
  ```

- read
  ```vault policy read <policy name>```, e.g. read the previously created policy: ```vault policy read admin```

