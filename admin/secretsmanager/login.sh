#!/bin/sh
set -e
# export INSTANCE_CRN=crn:v1:bluemix:public:secrets-manager:us-south:a/713c783d9a507a53135fe6793c37cc74:52cf281e-26aa-4ff3-817a-b33215fd1130::

if [ "x$VAULT_ADDR" == x ]; then
  echo required to have VAULT_ADDR in the environment to use the vault cli.
  echo export VAULT_ADDR=https://....
  exit 1
else
  if ! grep -q secrets-manager <<< "$VAULT_ADDR"; then
    echo VAULT_ADDR is not set to a secrets-manager url: $VAULT_ADDR
    exit 2
  fi
fi

authorization=$(ibmcloud iam oauth-tokens --output json | jq -r '.iam_token')
MANAGER_ACCESS_TOKEN="${authorization##* }";#strip off first word which is bearer

# get the vault client token using the iam bearer token
login_info=$(vault write -format=json auth/ibmcloud/login token=$MANAGER_ACCESS_TOKEN)
client_token=$(echo "$login_info" | jq -r .auth.client_token)

# login using the client token by copying the token to ~/.vault-token for use by future vault commands
vault login $client_token

echo
cat <<EOF
See the bin/functions.sh for lots of examples.  try:
  vault read auth/ibmcloud/manage/groups
EOF
