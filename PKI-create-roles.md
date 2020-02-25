# creating roles to fetch certificate

### create role (generic one)

```export VAULT_ALLOWED_DOMAIN="democompany.com"```

```bash
curl --silent --header "X-Vault-Token: "$VAULT_TOKEN \
--request POST --data '{"allowed_domains":"'$VAULT_ALLOWED_DOMAIN'","allow_subdomains":true,"max_ttl":"720h"}' \
$VAULT_ADDR/v1/vault-demo-ca/roles/generate-cert-role || true
```

We can further fine grain the roles to e.g. split into categories for _kafka broker_ and _kafka client_. It would be even better to have two dedicated intermediate CAs for both.  

#### create role (kafka-broker)

```export VAULT_ALLOWED_DOMAIN="democompany.com"```

```bash
cat <<- EOF > /tmp/kafka-broker-role.json
{
  "allowed_domains": "$VAULT_ALLOWED_DOMAIN",
  "allow_subdomains": true,
  "max_ttl": "720h",
  "allow_server" : true,
  "enforce_hostnames" : false, 
  "allow_client" : true,
  "allow_any_name" : true,
  "allow_bare_domains" : true
}
EOF

curl --header "X-Vault-Token: $VAULT_TOKEN" \
--request POST \
--data @/tmp/kafka-broker-role.json \
$VAULT_ADDR/v1/vault-demo-ca/roles/kafka-broker
```

#### create role (kafka-client)

```bash
cat <<- EOF > /tmp/kafka-client-role.json
{
  "allowed_domains": "$VAULT_ALLOWED_DOMAIN",
  "allow_subdomains": true,
  "max_ttl": "30m",
  "allow_server" : false,
  "enforce_hostnames" : false, 
  "allow_client" : true,
  "allow_any_name" : false,
  "allow_bare_domains" : true
}
EOF

curl --header "X-Vault-Token: $VAULT_TOKEN" \
--request POST \
--data @/tmp/kafka-client-role.json \
$VAULT_ADDR/v1/vault-demo-ca/roles/kafka-client
```
