#!/bin/bash
# secrets manager api key generation for each of the teams (not the admin team)
set -ex

export VAULT_ADDR=$(terraform output -state=admin/terraform.tfstate VAULT_ADDR)
SECRETS_MANAGER_GROUP_ID_NETWORK=$(terraform output -state=admin/terraform.tfstate SECRETS_MANAGER_GROUP_ID_NETWORK)
SECRETS_MANAGER_SECRET_ID_NETWORK=$(terraform output -state=admin/terraform.tfstate SECRETS_MANAGER_SECRET_ID_NETWORK)
./admin/secretsmanager/login.sh
function team_local_env {
  team=$1
    local read_creds_json=$(vault read -format=json ibmcloud/iam_credentials/creds/groups/$SECRETS_MANAGER_GROUP_ID_NETWORK/$SECRETS_MANAGER_SECRET_ID_NETWORK)
    echo export TF_VAR_ibmcloud_api_key=$(echo "$read_creds_json" | jq -r .data.api_key) > local.env
}

# admin uses the root apikey so skip it.
#for team in network shared application1 application2; do
for team in network ; do
  (
  cd $team
  team_local_env $team
  )
done
