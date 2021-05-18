# shared.widgets.com
resource ibm_dns_resource_record "shared_lb" {
  count       = var.shared_lb ? 1 : 0 # shared load balancer?
  instance_id = local.network_context.dns.guid
  zone_id     = local.network_context.dns.zone_id
  type        = "CNAME"
  name        = "shared"
  rdata       = ibm_is_lb.shared_lb[0].hostname
  ttl         = 3600
}

#-------------------------------------------------------------------

resource "ibm_is_lb" "shared_lb" {
  count          = var.shared_lb ? 1 : 0 # shared load balancer?
  name           = "shared-lb"
  resource_group = data.ibm_resource_group.shared.id
  type           = "private"
  subnets = [
    local.network_context.subnets["z1"].id,
    local.network_context.subnets["z2"].id,
  ]
  security_groups = [
    local.network_context.security_group_data_inbound.id,
    local.network_context.security_group_data_outbound.id,
  ]
}

resource "ibm_is_lb_listener" "shared_lb_listener" {
  count        = var.shared_lb ? 1 : 0 # shared load balancer?
  lb           = ibm_is_lb.shared_lb[0].id
  port         = "3000"
  protocol     = "http"
  default_pool = ibm_is_lb_pool.shared_lb_pool[0].id
}

resource "ibm_is_lb_pool" "shared_lb_pool" {
  count               = var.shared_lb ? 1 : 0 # shared load balancer?
  name                = "shared-lb-pool"
  lb                  = ibm_is_lb.shared_lb[0].id
  algorithm           = "round_robin"
  protocol            = "http"
  health_delay        = 60
  health_retries      = 5
  health_timeout      = 30
  health_type         = "http"
  health_monitor_url  = "/info"
  health_monitor_port = 3000
}

resource "ibm_is_lb_pool_member" "shared_lb_pool_member" {
  count          = var.shared_lb ? 1 : 0 # shared load balancer?
  lb             = ibm_is_lb.shared_lb[0].id
  pool           = ibm_is_lb_pool.shared_lb_pool[0].id
  port           = 3000
  target_address = ibm_is_instance.vsishared.primary_network_interface[0].primary_ipv4_address
}
