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

data ibm_resource_group "shared" {
  name = "${var.basename}-shared"
}

data ibm_is_ssh_key "ssh_key" {
  name = var.ssh_key_name
}

data ibm_is_image "image" {
  name = var.image
}

module user_data_app {
  source    = "../common/user_data_app"
  remote_ip = "REMOTE_IP" # no remote ip
}

locals {
  network_context = data.terraform_remote_state.network.outputs.shared
  # instance inbound is directly from the load balancer sg if available otherwise from the cidr block
  inbound_security_group_data = var.shared_lb ? local.network_context.security_group_data_inbound_from_outbound.id : local.network_context.security_group_data_inbound.id
}

resource ibm_is_instance "vsishared" {
  name           = "${var.basename}-shared-vsi"
  vpc            = local.network_context.vpc.id
  resource_group = data.ibm_resource_group.shared.id
  zone           = local.network_context.subnets["z1"].zone
  keys           = [data.ibm_is_ssh_key.ssh_key.id]
  image          = data.ibm_is_image.image.id
  profile        = var.profile

  primary_network_interface {
    subnet = local.network_context.subnets["z1"].id
    security_groups = [
      local.network_context.security_group_outbound_all.id, # nodejs is not available on an IBM mirror
      local.network_context.security_group_ibm_dns.id,
      local.inbound_security_group_data,
      local.network_context.security_group_data_inbound.id,
    ]
  }
  # user_data = module.user_data_app.user_data_centos
  user_data = module.user_data_app.user_data_ubuntu
}

#-------------------------------------------------------------------
# shared.widgets.com
resource ibm_dns_resource_record "shared" {
  count       = var.shared_lb ? 0 : 1 # shared load balancer?
  instance_id = local.network_context.dns.guid
  zone_id     = local.network_context.dns.zone_id
  type        = "A"
  name        = "shared"
  rdata       = ibm_is_instance.vsishared.primary_network_interface[0].primary_ip.0.address
  ttl         = 3600
}

#-------------------------------------------------------------------
resource ibm_is_floating_ip "vsishared" {
  resource_group = data.ibm_resource_group.shared.id
  name           = "${var.basename}-vsishared"
  target         = ibm_is_instance.vsishared.primary_network_interface[0].id
}

output ibm1_public_ip {
  value = ibm_is_floating_ip.vsishared.address
}

output ibm1_private_ip {
  value = ibm_is_instance.vsishared.primary_network_interface[0].primary_ip.0.address
}

output ibm1_curl {
  value = <<EOS

Verify these do not work:
curl ${ibm_is_floating_ip.vsishared.address}:3000; # get hello world string
curl ${ibm_is_floating_ip.vsishared.address}:3000/info; # get the private IP address
EOS
}
