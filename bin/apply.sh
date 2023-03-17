#!/bin/bash
set -e

basename='undefined'
function create_application2_from_application1 {
  (
    echo '>>> create application 2 from application 1'
    cd application1
    mkdir -p ../application2
    sed -e 's/application1/application2/g' main.tf > ../application2/main.tf
    cp .terraform.lock.hcl terraform.tfvars variables.tf versions.tf ../application2
  )
}
function initialize_basename_region {
  # get the basename from the terraform configuration file
  eval $(grep basename terraform.tfvars | sed -e 's/  *//g' -e 's/#.*//')
  echo basename=$basename
  eval $(grep ibm_region terraform.tfvars | sed -e 's/  *//g' -e 's/#.*//')
  echo ibm_region=$ibm_region
}
function admin_local_env {
  (
    echo '>>> create admin/local.env'
    cd admin
    [ -e local.env ] || echo export TF_VAR_ibmcloud_api_key=$(ibmcloud iam api-key-create $basename-admin --output json | jq .apikey) > local.env
  )
}
function terraform_init_apply {
  source ./local.env
  terraform init
  terraform apply -auto-approve -no-color
}
function team_local_env {
  team=$1
  [ -e local.env ] || echo export TF_VAR_ibmcloud_api_key=$(ibmcloud iam service-api-key-create $team $basename-$team --output json | jq .apikey) > local.env
}
function terraform_apply {
  source ./local.env
  terraform apply -auto-approve -no-color
}
function test_it {
  local times=$1
  local sleep=$2
  cmd="$3"
  for i in $(seq $times); do
    if eval $cmd; then
      return 0
    fi
    sleep $sleep
  done
  echo test failed
  return 1
}
function test_local_endpoint {
  (
    echo '>>> test application1'
    cd application1
    local cmd="$(terraform output -raw test_info)"
    echo can this workstation reach application1 instance? $cmd
    test_it 3 1 "$cmd"
  )
}
function test_remote_endpoint {
  (
    echo '>>> test application1'
    cd application1
    local cmd="$(terraform output -raw test_remote)"
    echo can application1 instance reach the shared instance? $cmd
    test_it 3 5 "$cmd"
  )
}
function test_local_and_remote {
  test_local_endpoint
  test_remote_endpoint
}

##################################################
create_application2_from_application1
initialize_basename_region
if ! ibmcloud target -r $ibm_region; then
  echo
  echo This command failed: ibmcloud target -r $ibm_region
  echo 'Probably not logged in via the cli, ibmcloud login ..., you will need to log in as an administrator of the account'
  exit 1
fi
admin_local_env
(
  echo '>>> admin/apply'
  cd admin
  terraform_init_apply
)
for team in admin network shared application1 application2; do
  (
  echo ">>> $team/apply"
  cd $team
  team_local_env $team
  terraform_init_apply
  )
done
test_local_endpoint
  
# turn on transit gateway and build network again
team=network
(
  echo ">>> $team/apply"
  export TF_VAR_transit_gateway=true
  cd $team
  terraform_apply
)
test_local_and_remote

# turn on load balancer and build shared again
team=shared
(
  echo ">>> $team/apply"
  export TF_VAR_shared_lb=true
  cd $team
  terraform_apply
)
test_local_and_remote

echo SUCCESS
