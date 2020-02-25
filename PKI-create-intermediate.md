##### Anlegen der Intermediate CA engine und max_lease_time setzen

```bash
curl --header "X-Vault-Token: $VAULT_TOKEN" \
--request POST \
--data '{"type":"pki"}' \
$VAULT_ADDR/v1/sys/mounts/vault-demo-ca

curl --header "X-Vault-Token: $VAULT_TOKEN" \
--request POST \
--data '{"max_lease_ttl":"43800h"}' \
$VAULT_ADDR/v1/sys/mounts/vault-demo-ca/tune
```

##### CertificateRevokationList (CRL) für Intermediate CA erstellen

```bash
cat > /tmp/payload-url-intermediate.json <<- EOF
{
  "issuing_certificates": "$VAULT_ADDR/v1/vault-demo-ca/ca",
  "crl_distribution_points": "$VAULT_ADDR/v1/vault-demo-ca/crl"
}
EOF

curl --header "X-Vault-Token: $VAULT_TOKEN" \
     --request POST \
     --data @/tmp/payload-url-intermediate.json \
     $VAULT_ADDR/v1/vault-demo-ca/config/urls
```


##### Intermediate Zertifikat erzeugen

  - create CSR for intermediate
  
```bash
cat <<- EOF > /tmp/payload-intermediate-cert.json
{
  "common_name": "vault-demo-intermediate"
}
EOF

# generate the intermediate cert CSR
curl -s --header "X-Vault-Token: $VAULT_TOKEN" \
--request POST \
--data @/tmp/payload-intermediate-cert.json \
$VAULT_ADDR/v1/vault-demo-ca/intermediate/generate/internal | jq -r ".data"
```

  - sign CSR
    ```bash
    vi /tmp/payload-int-cert.json # add following content. CSR is the cert output of previous command !!
    {
      "csr": "-----BEGIN CERTIFICATE REQUEST-----\nMIICn.........olNje6x\n-----END CERTIFICATE REQUEST-----",
      "format": "pem_bundle",
      "ttl": "43800h"
    }

    curl -s --header "X-Vault-Token: $VAULT_TOKEN" \
       --request POST \
       --data @/tmp/payload-int-cert.json \
       $VAULT_ADDR/v1/rootca/root/sign-intermediate | jq -r ".data"
    ```

    Response contains signed intermediate cert in _certificate_ . This has to be imported into Vault now.  

  - import (signed) intermediate cert into Vault 

    ```bash
    vi /tmp/payload-signed-intermediate.json # with content

    {
      "certificate": "-----BEGIN CERTIFICATE-----\nMIIDx............JVOc1cUU=\n-----END CERTIFICATE-----"
    }

    curl --header "X-Vault-Token: $VAULT_TOKEN" \
        --request POST \
        --data @/tmp/payload-signed-intermediate.json \
        $VAULT_ADDR/v1/vault-demo-ca/intermediate/set-signed
    ```
