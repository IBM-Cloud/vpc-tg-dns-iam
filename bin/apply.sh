#!/bin/bash
set -ex

# create the application2 team from the application1 team
if ! [ -d application2 ]; then
(
  cd application1
  mkdir ../application2
  sed -e 's/application1/application2/g' main.tf > ../application2/main.tf
  cp terraform.tfvars variables.tf ../application2
)
fi

# get the basename from the terraform configuration file
eval $(grep basename terraform.tfvars | sed -e 's/  *//g' -e 's/#.*//')
echo basename=$basename

# terraform the admin team
(
  cd admin
  [ -e local.env ] || echo export TF_VAR_ibmcloud_api_key=$(ibmcloud iam api-key-create $basename-admin --output json | jq .apikey) > local.env
  source local.env
  terraform init
  terraform apply -auto-approve
)

# terraform the rest of the teams - all teams except the admin team
for team in admin network shared application1 application2; do
  (
    cd $team
    [ -e local.env ] || echo export TF_VAR_ibmcloud_api_key=$(ibmcloud iam service-api-key-create $team $basename-$team --output json | jq .apikey) > local.env
    source ./local.env
    terraform init
    terraform apply -auto-approve
  )
done
