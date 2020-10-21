#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
set -e
set -x

echo SERVICE_ID_SM_IAM_ENGINE = $SERVICE_ID_SM_IAM_ENGINEVAULT_ADDR
echo SERVICE_API = $SERVICE_API
echo ADMIN_API_KEY = $ADMIN_API_KEY

authorization=undefined
function authorization_create() {
  # bearer token
  if [ $authorization == undefined ]; then
    authorization=$(ibmcloud iam oauth-tokens --output json | jq -r '.iam_token')
  fi
}

# settings IAM -------------------------
function iam_credentials_exist() {
  authorization_create
  local iam_credentials_json=$(curl -X GET -H "Authorization: $authorization" -H "Accept: application/json" "$SERVICE_API/v1/config/iam_credentials")
  echo "$iam_credentials_json" | jq -e '.resources[0].api_key_hash' > /dev/null 2>&1
}
function iam_credentials_put() {
  if ! iam_credentials_exist; then
    local service_id_uuid=$SERVICE_ID_SM_IAM_ENGINE
    local service_api_key_create_output=$(ibmcloud iam service-api-key-create secrets_manager $service_id_uuid --output json)
    local apikey=$(echo "$service_api_key_create_output" | jq -r .apikey)
    curl -X PUT -H "Authorization: $authorization" -H "Content-Type: application/json" -d '{ "api_key": "'$apikey'"}' "$SERVICE_API/v1/config/iam_credentials"
  fi
}
function iam_credentials_delete() {
  echo not possible to delete
}


# verify expected global variables are set
# export API_KEY=$TF_VAR_ibmcloud_api_key
ibmcloud login --apikey $ADMIN_API_KEY
ibmcloud login --apikey $API_KEY; #needed for vault login
if [ $1 == create ]; then
  iam_credentials_put
fi
if [ $1 == delete ]; then
  echo deleted
fi
