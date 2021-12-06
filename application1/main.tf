provider ibm {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.ibm_region
}

data terraform_remote_state "network" {
  backend = "local"
  config = {
    path = "${path.module}/../network/terraform.tfstate"
  }
}

data ibm_resource_group "application1" {
  name = "${var.basename}-application1"
}

data ibm_is_ssh_key "ssh_key" {
  name = var.ssh_key_name
}

data ibm_is_image "image" {
  name = var.image
}

module user_data_app {
  source    = "../common/user_data_app"
  remote_ip = "shared.widgets.com"
}

locals {
  network_context = data.terraform_remote_state.network.outputs.application1
}

resource ibm_is_instance "vsiapplication1" {
  name           = "${var.basename}-application1-vsi"
  vpc            = local.network_context.vpc.id
  resource_group = data.ibm_resource_group.application1.id
  zone           = local.network_context.subnets["z1"].zone
  keys           = [data.ibm_is_ssh_key.ssh_key.id]
  image          = data.ibm_is_image.image.id
  profile        = var.profile

  primary_network_interface {
    subnet = local.network_context.subnets["z1"].id
    security_groups = [
      local.network_context.security_group_ssh.id, # add to ssh and debug
      #local.network_context.security_group_install_software.id, #centos nodejs is not available on an IBM mirror use outbound_all
      local.network_context.security_group_outbound_all.id,          # centos nodejs is not available on an IBM mirror
      local.network_context.security_group_ibm_dns.id,               # local dns
      local.network_context.security_group_data_inbound_insecure.id, # curl from my desktop
    ]
  }
  # user_data = module.user_data_app.user_data_centos
  user_data = module.user_data_app.user_data_ubuntu
}

resource ibm_is_floating_ip "vsiapplication1" {
  resource_group = data.ibm_resource_group.application1.id
  name           = "${var.basename}-vsiapplication1"
  target         = ibm_is_instance.vsiapplication1.primary_network_interface[0].id
}

#-------------------------------------------------------------------
output ibm1_public_ip {
  value = ibm_is_floating_ip.vsiapplication1.address
}

output ibm1_private_ip {
  value = ibm_is_instance.vsiapplication1.primary_network_interface[0].primary_ipv4_address
}

output test_info {
  value = "curl ${ibm_is_floating_ip.vsiapplication1.address}:3000/info"
}
output test_remote {
  value = "curl ${ibm_is_floating_ip.vsiapplication1.address}:3000/remote"
}
