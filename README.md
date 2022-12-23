# VPCs with Transit Gateway and DNS Services
This is the companion github repository for the solution tutorial https://cloud.ibm.com/docs/solution-tutorials?topic=solution-tutorials-vpc-tg-dns-iam

This repository: https://github.com/IBM-Cloud/vpc-tg-dns-iam

This tutorial walks you through creating the account resource groups and IAM access groups to organize independent devops teams to develop and maintain applications.  Each devop team administers the VPC instances, VSIs, but not the static network infrastructure like the creation of CIDR blocks and subnets.  The VPCs are connected by Transit Gateways.  The shared devops team has a service **shared.widgets.example.com** that is put into the DNS service.

# TLDR;
There is an apply.sh shell script that will simply perform all of the steps in the tutorial.  There is a destroy.sh shell script that destroys all of the resources.

```
git clone https://github.com/IBM-Cloud/vpc-tg-dns-iam
cd vpc-tg-dns-iam
cp terraform.tfvars.template terraform.tfvars
edit terraform.tfvars
ibmcloud login; # login using credentials or apikey
./bin/apply.sh
# test it out
./bin/destroy.sh
```

# IAM and Access Groups

Team structure
- Admin team can add members and assign resources for the other teams
- Network team can create the VPC, subnets, ACLs etc
- Shared team deploys VSIs and software on the VSIs and configures it's DNS names
- Application team deploys VSIs and software on the VSIs


# Becoming a team member
If you did not run the complete `./bin/apply.sh` you can do it for each team individually.

It is possible to populate each team's access group with users.  In this example you are the administrator and will **become** a member of the different access groups by using api keys for yourself, the admin user, or from the service IDs that will be in the other access groups.  The service ID names are ${basename}-x where x is network, shared, application1 and application2.  Later you will populate a `local.env` file in each team's directory with contents similar to this:
```
export TF_VAR_ibmcloud_api_key=0thisIsNotARealKeyALX0vkLNSUFC7rMLEWYpVtyZaS9
```
When you cd into a directory you will be reminded to execute: `source local.env`

## Getting Started
Edit the terraform.tfvars file used by all of the teams, initialize the basename shell variable to match the terraform.tfvars file.
```
cp terraform.tfvars.template terraform.tfvars
edit terraform.tfvars
eval $(grep basename terraform.tfvars | sed -e 's/  *//g' -e 's/#.*//')
echo basename=$basename
```
## Admin Team

After fetching the source code and making the initial terraform.tfvars changes suggested above set current directory to ./admin and use the `ibmcloud iam api-key-create` command to create an api key for the admin.  This is the same as a password to your account and it will be used by terraform to perform tasks on your behalf.  Keep the api key safe.

```
cd admin
echo export TF_VAR_ibmcloud_api_key=$(ibmcloud iam api-key-create $basename-admin --output json | jq .apikey) > local.env
cat local.env
source local.env
```
## Shared Team
Change directory, generate an API key in the local.env and become a member of the shared access group:

```
team=shared
cd ../$team
echo export TF_VAR_ibmcloud_api_key=$(ibmcloud iam service-api-key-create $team $basename-$team --output json | jq .apikey) > local.env
cat local.env
source local.env
terraform apply
```

## Application1 Team
Change directory, generate an API key in the local.env and become a member of the application1 access group:

```
team=application1
cd ../$team
echo export TF_VAR_ibmcloud_api_key=$(ibmcloud iam service-api-key-create $team $basename-$team --output json | jq .apikey) > local.env
cat local.env
source local.env
terraform apply
```


Results look something like this:

```
$ terraform apply
...
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

ibm1_curl =
ssh root@169.48.152.220
curl 169.48.152.220:3000; # get hello world string
curl 169.48.152.220:3000/info; # get the private IP address
curl 169.48.152.220:3000/remote; # get the remote private IP address
```

Try the curl commands suggested.  See something like what was captured below where the private IP address of 169.48.152.220 is 10.1.0.4 and the /remote (shared.widgets.example.com) is 10.0.0.4.

```
$ curl 169.48.152.220:3000/info

{
  "req_url": "/info",
  "os_hostname": "widget0-application1-vsi",
  "ipArrays": [
     [
        "10.1.0.4"
     ]
  ]
}

$ curl 169.48.152.220:3000/remote; # get the remote private IP address

{
  "remote_url": "http://shared.widgets.example.com:3000/info",
  "remote_ip": "10.0.0.4",
  "remote_info": {
     "req_url": "/info",
     "os_hostname": "widget0-shared-vsi",
     "ipArrays": [
        [
           "10.0.0.4"
        ]
     ]
  }
}
```

