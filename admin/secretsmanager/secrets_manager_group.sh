#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
set -e
set -x

echo ADMIN_API_KEY = $ADMIN_API_KEY
echo SECRET_GROUP_NAME = $SECRET_GROUP_NAME
echo SECRET_NAME = $SECRET_NAME
echo IAM_ACCESS_GROUP_IDS = $IAM_ACCESS_GROUP_IDS
echo VAULT_ADDR = $VAULT_ADDR
echo SECRETS_GROUP_FILE = $SECRETS_GROUP_FILE
echo SECRETS_FILE = $SECRETS_FILE
echo "ERRORHARDCODED" > $SECRETS_GROUP_FILE

# login -------------------------
vault_login_count=0
function vault_login() {
  if [[ $vault_login_count == 0 ]]; then
    $DIR/login.sh
  fi
  (( vault_login_count++ ))
  return 0
}
function vault_logout() {
  vault_login_count=0
  rm -f ~/.vault-token
}

# secret group -------------------------
SECRET_GROUP_ID=undefined
function secret_group_get() {
  if [ $SECRET_GROUP_ID == undefined ]; then
    vault_login
    local groups_json=$(vault read -format=json auth/ibmcloud/manage/groups)
    if echo "$groups_json" | jq -e '.data.groups[]|select(.name=="'$SECRET_GROUP_NAME'")' > /dev/null 2>&1 ; then
      SECRET_GROUP_ID=$(echo $groups_json | jq -r '.data.groups[]|select(.name=="'$SECRET_GROUP_NAME'")|.id')
    fi
  fi
  return 0
}
function secret_group_create() {
  secret_group_get
  if [ $SECRET_GROUP_ID == undefined ]; then
    local group_create_json=$(vault write --format=json auth/ibmcloud/manage/groups name=$SECRET_GROUP_NAME)
    SECRET_GROUP_ID=$(echo "$group_create_json" | jq -r '.data.id')
  fi
  return 0
}
function secret_group_delete() {
  secret_group_get
  if [ $SECRET_GROUP_ID != undefined ]; then
    vault delete auth/ibmcloud/manage/groups/$SECRET_GROUP_ID
    SECRET_GROUP_ID=undefined
  fi
  return 0
}

# secret for iam_credentials -------------------------
SECRET_ID=undefined
function secret_get() {
  secret_group_get
  if [ $SECRET_ID == undefined ]; then
    local secrets_json=$(vault read --format=json ibmcloud/iam_credentials/roles/groups/$SECRET_GROUP_ID)
    if echo "$secrets_json" | jq -e '.data.roles[]|select(.name=="'$SECRET_NAME'")'; then
      SECRET_ID=$(echo "$secrets_json" | jq -r '.data.roles[]|select(.name=="'$SECRET_NAME'")|.id')
    fi
  fi
  return 0
}
function secret_create() {
  local ttl=$1
  secret_get
  if [ $SECRET_ID == undefined ]; then
    local access_group="$IAM_ACCESS_GROUP_IDS"
    local secret_json=$(vault write --format=json ibmcloud/iam_credentials/roles/groups/$SECRET_GROUP_ID/$SECRET_NAME access_groups="$access_group" ttl=$ttl)
    SECRET_ID=$(echo "$secret_json" | jq -r .data.id)
  fi
  return 0
}
function secret_delete() {
  secret_get
  if [ $SECRET_ID != undefined ]; then
    vault delete ibmcloud/iam_credentials/roles/groups/$SECRET_GROUP_ID/$SECRET_ID
    SECRET_ID=undefined
  fi
  return 0
}

export API_KEY=$ADMIN_API_KEY
ibmcloud login --apikey $API_KEY; #needed for vault login

if [ $1 == create ]; then
  secret_group_create
  secret_create 1h
  echo $SECRET_GROUP_ID > $SECRETS_GROUP_FILE
  echo $SECRET_ID > $SECRETS_FILE
fi
if [ $1 == delete ]; then
  secret_delete
  secret_group_delete
  rm $SECRETS_GROUP_FILE
fi

