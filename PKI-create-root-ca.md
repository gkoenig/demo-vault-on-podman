### PKI management
Demo is doing a 2-level CA chain, means creation of an intermediate CA, signed by root ca (either Vault itself or outside vault).  

#### Root CA within Vault  
  
  - vault cli  
    ```vault secrets enable -path=rootca -description=”PKI backend for Root CA” -max-lease-ttl=87600h pki```  
    ```vault secrets tune -max-lease-ttl=87600h rootca```  
    
  - REST
  
    ```bash
    curl --header "X-Vault-Token: $VAULT_TOKEN" \
       --request POST \
       --data '{"type":"pki"}' \
        $VAULT_ADDR/v1/sys/mounts/rootca
    ```
  
    ```bash
    curl --header "X-Vault-Token: $VAULT_TOKEN" \
       --request POST \
       --data '{"max_lease_ttl":"87600h"}' \
        $VAULT_ADDR/v1/sys/mounts/rootca/tune
    ```

##### (Root-) CA Zertifikat und Key erzeugen:  
  
- vault cli  
  
    ```bash
    vault write -field=certificate rootca/root/generate/internal \
    common_name="vault-demo-ca" \
    ttl=87600h key_bits=4096 > /tmp/CA_cert.crt
    ```

- REST 
  
```bash
# create payload file
cat <<- EOF > /tmp/payload.json # with following content
{
  "common_name": "vault-demo-ca",
  "ttl": "87600h"
}
EOF

    # create CA and extract certificate
    curl --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data @/tmp/payload.json \
    $VAULT_ADDR/v1/rootca/root/generate/internal | jq -r ".data.certificate" > /tmp/CA_cert.crt
    ```

- CA Zertifikat manuell auslesen:  
  ```curl -s --header "X-Vault-Token: $VAULT_TOKEN" $VAULT_ADDR/v1/rootca/ca/pem```

- CertificateRevokationList (CRL) erstellen

```bash  
cat <<- EOF > /tmp/payload-url.json
{
  "issuing_certificates": "$VAULT_ADDR/v1/rootca/ca",
  "crl_distribution_points": "$VAULT_ADDR/v1/rootca/crl"
}
EOF

  curl --header "X-Vault-Token: $VAULT_TOKEN" \
        --request POST \
        --data @/tmp/payload-url.json \
        $VAULT_ADDR/v1/rootca/config/urls
```