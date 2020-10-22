#!/bin/bash
# secrets manager api key generation for each of the teams (not the admin team)
#
# A team member that is in the access group for the team secret group can create an api key
# that has access to the team resources.
#
# team-admin - secrets manager group
set -e

function initialize_basename {
  # get the basename from the terraform configuration file
  eval $(grep basename terraform.tfvars | sed -e 's/  *//g' -e 's/#.*//')
  echo basename=$basename
}

initialize_basename
export VAULT_ADDR=$(terraform output -state=admin/terraform.tfstate VAULT_ADDR)
SECRETS_MANAGER_GROUP_ID_NETWORK=$(terraform output -state=admin/terraform.tfstate SECRETS_MANAGER_GROUP_ID_NETWORK)
SECRETS_MANAGER_SECRET_ID_NETWORK=$(terraform output -state=admin/terraform.tfstate SECRETS_MANAGER_SECRET_ID_NETWORK)
function team_local_env {
  team=$1
    # become a team member of the access group associated with the secrets manager group
    export TF_VAR_ibmcloud_api_key=$(ibmcloud iam service-api-key-create $team $basename-$team-admin --output json | jq -r .apikey)
    ../admin/secretsmanager/login.sh
    # create the dynamic api key that has access to the team resources
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
