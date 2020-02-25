# Hashicorp Vault on Podman

Links:  
[Hashicorp Vault](https://www.vaultproject.io/)  
[Podman](https://podman.io/getting-started/)

## container setup

- [Intro Podman](./podman-intro.md)  
- [Start Vault via Podman pod](./start-vault.md)

## using Vault

## secrets

- [managing KV-secrets](managing-kv-secrets.md)
- managing PKI
  - [creating root CA](PKI-create-root-ca.md)
  - [optional: create root CA outside of Vault](PKI-create-root-ca-outside-vault.md)
  - [creating intermediate](PKI-create-intermediate.md)
  - [creating role(s) to fetch certificate(s)](PKI-create-roles.md)

Now, you can generate certificate(s) by still using the root vault token. This is fine for the moment, but
not recommended for production environments. There you should use dedicated users/tokens including policies.  

- generate a (kafka-broker-)certificate

```bash
DOMAIN_NAME="kafka-broker-1"
curl --silent --header "X-Vault-Token: "$VAULT_TOKEN \
  --request POST --data '{"common_name":"'$DOMAIN_NAME'"}' \
  $VAULT_ADDR/v1/vault-demo-ca/issue/kafka-broker
```

- generate a (kafka-client-)certificate

```bash
DOMAIN_NAME="kafka-client-1.democompany.com"
curl --silent --header "X-Vault-Token: "$VAULT_TOKEN \
  --request POST --data '{"common_name":"'$DOMAIN_NAME'"}' \
  $VAULT_ADDR/v1/vault-demo-ca/issue/kafka-client
```

> This step will do the following:  
>
> - private key
> - public key
> - certificate chain / ca_chain comprising of the public key of issuing CA. By default, it will include only 1  certificate same as issuing_ca. When uploading certificate data to the application, you will need to add certificate a public key of root CA server to the certificate chain, so the applications will trust the certificate.
>
> Now you need to extract private_key, ca_chain (and add public cert of root certificate to it) and, certificate.
>
> - certificate
> - private_key
> - ca_chain (!! add the public key of the main CA, the one you created with _cfssl_ !!) 

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

Policies for kafka-client and kafka-broker:

```bash
cat > /tmp/kafka-client.json << EOF
{
  "policy": "path \"vault-demo-ca/issue/kafka-client\" { capabilities=[\"create\",\"update\",\"read\",\"list\"] }"
}
EOF

cat > /tmp/kafka-broker.json << EOF
{
  "policy": "path \"vault-demo-ca/issue/kafka-broker\" { capabilities=[\"create\",\"update\",\"read\",\"list\"] }"
}
EOF

curl --header "X-Vault-Token: $VAULT_TOKEN" \
--request POST \
--data @/tmp/kafka-client.json \
$VAULT_ADDR/v1/sys/policies/acl/kafka-client

curl --header "X-Vault-Token: $VAULT_TOKEN" \
--request POST \
--data @/tmp/kafka-broker.json \
$VAULT_ADDR/v1/sys/policies/acl/kafka-broker
```

### check policies
- list
  ```vault policy list```  
  or, by REST  
  
  ```bash
  curl --request LIST --header "X-Vault-Token: $VAULT_TOKEN" \
       $VAULT_ADDR/v1/sys/policies/acl | jq
  ```

- read
  ```vault policy read <policy name>```, e.g. read the previously created policy: ```vault policy read admin```

## auth methods
Vault offers several methods for authentication. So far we used _token based_ auth , with the root token.  
To use another method (user/passwd, AWS/Azure/GCP, Github, LDAP, ....) you have to enable the corresponding method first.

### authentication via Github
- enable auth method 
  ```vault auth enable github```
- configure the method, if applicable
  ```vault write auth/github/config organization=your-org```  
- map users/teams of that organization to policies
  ```vault write auth/github/map/teams/dev value=dev-policy```  
  In this example, when members of the team "dev" in the organization "Scigility" authenticate to Vault using a GitHub personal access token, they will be given a token with the "dev-policy" policy attached.
  The same can also be done for single users, by talking to the _users_ endpoint  
  ```vault write auth/github/map/users/gerd value=gerd-policy```
- check the auth backend
  ```vault read auth/github/config```

### appRole auth

- enable appRole auth and check afterwards  

```bash
curl -X POST -H "X-Vault-Token:$VAULT_TOKEN" -d '{"type":"approle"}' $VAULT_ADDR/v1/sys/auth/approle
curl -X GET -H "X-Vault-Token:$VAULT_TOKEN" $VAULT_ADDR/v1/sys/auth
```

- create policy

```bash
curl -X POST -H "X-Vault-Token:$VAULT_TOKEN" -d '{"rules": "{\"name\": \"dev\", \"path\": {\"secret/*\": {\"policy\": \"write\"}}}"}' $VAULT_ADDR/v1/sys/policy/dev
curl -X GET -H "X-Vault-Token:$VAULT_TOKEN" $VAULT_ADDR/v1/sys/policy/dev
```

- create role and check afterwards

```bash
curl -X POST -H "X-Vault-Token:$VAULT_TOKEN" -d '{"policies":"kafka-broker"}' $VAULT_ADDR/v1/auth/approle/role/kafka-broker
curl -X GET -H "X-Vault-Token:$VAULT_TOKEN" $VAULT_ADDR/v1/auth/approle/role\?list\=true
```

- get role-id and secret-id for auth against Vault for retrieving a token

```bash
curl -s -X GET -H "X-Vault-Token:$VAULT_TOKEN" $VAULT_ADDR/v1/auth/approle/role/kafka-broker/role-id | jq -r .data.role_id
curl -s -X POST -H "X-Vault-Token:$VAULT_TOKEN" $VAULT_ADDR/v1/auth/approle/role/kafka-broker/secret-id | jq -r .data.secret_id
# now get the token
export VAULT_TOKEN=$(curl -s -X POST -d '{"role_id":"5ba434a9-97ba-5efb-262c-ece73aff2890","secret_id":"844d5004-a835-3217-f8a4-031ac17b3f06"}' $VAULT_ADDR/v1/auth/approle/login) | jq -r .data.auth.client_token
```

- try to get a certificate

```bash
DOMAIN_NAME="kafka-broker-1"
curl --silent --header "X-Vault-Token: "$VAULT_TOKEN \
  --request POST --data '{"common_name":"'$DOMAIN_NAME'"}' \
  $VAULT_ADDR/v1/vault-demo-ca/issue/kafka-broker
```

### token auth

**kafka-client**

```bash
cat <<- EOF > /tmp/kafka-client-token.json
{
  "policies": ["kafka-client"],
  "ttl": "1h",
  "renewable": true
}
EOF
```

```bash
_response=$(curl -s --header "X-Vault-Token: $VAULT_TOKEN" --request POST --data @/tmp/kafka-client-token.json $VAULT_ADDR/v1/auth/token/create)
## set VAULT_TOKEN to the received one
export VAULT_TOKEN=$(echo $_response | jq -r ".auth.client_token")

## and try to grab a certificate (!! this should fail, due to the fact we want to grab a kafka-broker cert !!)
DOMAIN_NAME="kafka-broker-100"
curl --silent --header "X-Vault-Token: "$VAULT_TOKEN \
  --request POST --data '{"common_name":"'$DOMAIN_NAME'"}' \
  $VAULT_ADDR/v1/vault-demo-ca/issue/kafka-broker

## try to grab a certificate for kafka-client, this should work
DOMAIN_NAME="kafka-client-100"
curl --silent --header "X-Vault-Token: "$VAULT_TOKEN \
  --request POST --data '{"common_name":"'$DOMAIN_NAME'"}' \
  $VAULT_ADDR/v1/vault-demo-ca/issue/kafka-client

```

**kafka-broker_**

```bash
cat <<- EOF > /tmp/kafka-broker-token.json
{
  "policies": ["kafka-broker"],
  "ttl": "10h",
  "renewable": true
}
EOF

_response=$(curl -s --header "X-Vault-Token: $VAULT_TOKEN" --request POST --data @/tmp/kafka-broker-token.json $VAULT_ADDR/v1/auth/token/create)
## set VAULT_TOKEN to the received one
export VAULT_TOKEN=$(echo $_response | jq -r ".auth.client_token")

## and try to grab a certificate, for kafka-broker
DOMAIN_NAME="kafka-broker-100"
curl --silent --header "X-Vault-Token: "$VAULT_TOKEN \
  --request POST --data '{"common_name":"'$DOMAIN_NAME'"}' \
  $VAULT_ADDR/v1/vault-demo-ca/issue/kafka-broker

## try to grab a certificate for kafka-client, this should work
DOMAIN_NAME="kafka-client-100"
curl --silent --header "X-Vault-Token: "$VAULT_TOKEN \
  --request POST --data '{"common_name":"'$DOMAIN_NAME'"}' \
  $VAULT_ADDR/v1/vault-demo-ca/issue/kafka-client

```
