#### Root CA via cfssl

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