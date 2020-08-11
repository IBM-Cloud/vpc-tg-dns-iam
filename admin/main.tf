provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.ibm_region
  generation       = var.generation
}

output basename {
  value = var.basename
}

# ---------------- resource groups
resource "ibm_resource_group" "network" {
  name = "${var.basename}-network"
}
resource "ibm_resource_group" "shared" {
  name = "${var.basename}-shared"
}
resource "ibm_resource_group" "application1" {
  name = "${var.basename}-application1"
}
resource "ibm_resource_group" "application2" {
  name = "${var.basename}-application2"
}

# ---------------- access groups and a service id in each group
# network
resource "ibm_iam_access_group" "network" {
  name        = "${var.basename}-network"
  description = "network administrators"
}
resource "ibm_iam_service_id" "network" {
  name        = "${var.basename}-network"
  description = "network service id"
}
resource "ibm_iam_access_group_members" "network" {
  access_group_id = ibm_iam_access_group.network.id
  iam_service_ids = [ibm_iam_service_id.network.id]
}

# shared
resource "ibm_iam_access_group" "shared" {
  name        = "${var.basename}-shared"
  description = "shared administrators"
}
resource "ibm_iam_service_id" "shared" {
  name        = "${var.basename}-shared"
  description = "shared service id"
}
resource "ibm_iam_access_group_members" "shared" {
  access_group_id = ibm_iam_access_group.shared.id
  iam_service_ids = [ibm_iam_service_id.shared.id]
}

# application1
resource "ibm_iam_access_group" "application1" {
  name        = "${var.basename}-application1"
  description = "application1 administrators"
}
resource "ibm_iam_service_id" "application1" {
  name        = "${var.basename}-application1"
  description = "application 1 service id"
}
resource "ibm_iam_access_group_members" "application1" {
  access_group_id = ibm_iam_access_group.application1.id
  iam_service_ids = [ibm_iam_service_id.application1.id]
}

# application2
resource "ibm_iam_access_group" "application2" {
  name        = "${var.basename}-application2"
  description = "application2 administrators"
}
resource "ibm_iam_service_id" "application2" {
  name        = "${var.basename}-application2"
  description = "application 2 service id"
}
resource "ibm_iam_access_group_members" "application2" {
  access_group_id = ibm_iam_access_group.application2.id
  iam_service_ids = [ibm_iam_service_id.application2.id]
}

# ---------------- viewer access to resource groups
resource "ibm_iam_access_group_policy" "network_policy" {
  access_group_id = ibm_iam_access_group.network.id
  roles           = ["Viewer"]
  for_each        = { network = ibm_resource_group.network.id, application1 = ibm_resource_group.application1.id, application2 = ibm_resource_group.application2.id, shared = ibm_resource_group.shared.id }
  resources {
    resource_type = "resource-group"
    resource      = each.value
  }
}

resource "ibm_iam_access_group_policy" "shared_policy" {
  access_group_id = ibm_iam_access_group.shared.id
  roles           = ["Viewer"]
  resources {
    resource_type = "resource-group"
    resource      = ibm_resource_group.shared.id
  }
}

resource "ibm_iam_access_group_policy" "application1_policy" {
  access_group_id = ibm_iam_access_group.application1.id
  roles           = ["Viewer"]
  resources {
    resource_type = "resource-group"
    resource      = ibm_resource_group.application1.id
  }
}

resource "ibm_iam_access_group_policy" "application2_policy" {
  access_group_id = ibm_iam_access_group.application2.id
  roles           = ["Viewer"]
  resources {
    resource_type = "resource-group"
    resource      = ibm_resource_group.application2.id
  }
}

# ---------------- network team only - transit gateway
resource "ibm_iam_access_group_policy" "transit" {
  access_group_id = ibm_iam_access_group.network.id
  roles           = ["Editor"]

  resources {
    service           = "transit"
    resource_group_id = ibm_resource_group.network.id
  }
}

# ---------------- dns can be created by the network team but managed by the shared team
resource "ibm_iam_access_group_policy" "dns_network" {
  access_group_id = ibm_iam_access_group.network.id
  roles           = ["Editor", "Manager"]

  resources {
    service           = "dns-svcs"
    resource_group_id = ibm_resource_group.shared.id
  }
}

resource "ibm_iam_access_group_policy" "dns-shared" {
  access_group_id = ibm_iam_access_group.shared.id
  roles           = ["Viewer", "Manager"]

  resources {
    service           = "dns-svcs"
    resource_group_id = ibm_resource_group.shared.id
  }
}

# ----------------------------------------------------------
# Infrastructure (is) resources (.i.e vpc)
# ----------------------------------------------------------
locals {
  # types of resources that just the network team manage
  is_network_service_types = {
    "networkAclId"       = "*"
    "vpnGatewayId"       = "*" # not in tutorial, included for completeness
    "publicGatewayId"    = "*" # not in tutorial, included for completeness
    "flowLogCollectorId" = "*" # not in tutorial, included for completeness
  }
  # types of resources that both the network team and the instance teams manage
  is_network_and_instance_service_types = {
    "vpcId"           = "*"
    "subnetId"        = "*"
    "securityGroupId" = "*"
  }
  # types of resources that just the instance teams manage
  is_instance_service_types = {
    "instanceId"      = "*"
    "volumeId"        = "*"
    "floatingIpId"    = "*"
    "keyId"           = "*"
    "imageId"         = "*"
    "loadBalancerId"  = "*"
    "instanceGroupId" = "*" # not in tutorial, included for completeness
    "dedicatedHostId" = "*" # not in tutorial, included for completeness
  }
}

# ---------------- is resources, shared and network resource group for the network team
resource "ibm_iam_access_group_policy" "networkshared_is_resources" {
  access_group_id = ibm_iam_access_group.network.id
  roles           = ["Editor"]

  for_each = merge(local.is_network_service_types, local.is_network_and_instance_service_types)
  resources {
    service = "is"
    attributes = {
      "${each.key}" = each.value
    }
    resource_group_id = ibm_resource_group.shared.id
  }
}
resource "ibm_iam_access_group_policy" "networkapplication1_is_resources" {
  access_group_id = ibm_iam_access_group.network.id
  roles           = ["Editor"]

  for_each = merge(local.is_network_service_types, local.is_network_and_instance_service_types)
  resources {
    service = "is"
    attributes = {
      "${each.key}" = each.value
    }
    resource_group_id = ibm_resource_group.application1.id
  }
}
resource "ibm_iam_access_group_policy" "networkapplication2_is_resources" {
  access_group_id = ibm_iam_access_group.network.id
  roles           = ["Editor"]

  for_each = merge(local.is_network_service_types, local.is_network_and_instance_service_types)
  resources {
    service = "is"
    attributes = {
      "${each.key}" = each.value
    }
    resource_group_id = ibm_resource_group.application2.id
  }
}

resource "ibm_iam_access_group_policy" "shared_is_network_operator_resources" {
  access_group_id = ibm_iam_access_group.shared.id
  roles           = ["Operator"]

  for_each = local.is_network_and_instance_service_types
  resources {
    service = "is"
    attributes = {
      "${each.key}" = each.value
    }
    resource_group_id = ibm_resource_group.shared.id
  }
}
resource "ibm_iam_access_group_policy" "shared_is_instance_resources" {
  access_group_id = ibm_iam_access_group.shared.id
  roles           = ["Editor"]

  for_each = local.is_instance_service_types
  resources {
    service = "is"
    attributes = {
      "${each.key}" = each.value
    }
    resource_group_id = ibm_resource_group.shared.id
  }
}

resource "ibm_iam_access_group_policy" "application1_is_network_operator_resources" {
  access_group_id = ibm_iam_access_group.application1.id
  roles           = ["Operator"]

  for_each = local.is_network_and_instance_service_types
  resources {
    service = "is"
    attributes = {
      "${each.key}" = each.value
    }
    resource_group_id = ibm_resource_group.application1.id
  }
}
resource "ibm_iam_access_group_policy" "application1_is_instance_resources" {
  access_group_id = ibm_iam_access_group.application1.id
  roles           = ["Editor"]

  for_each = local.is_instance_service_types
  resources {
    service = "is"
    attributes = {
      "${each.key}" = each.value
    }
    resource_group_id = ibm_resource_group.application1.id
  }
}

resource "ibm_iam_access_group_policy" "application2_is_network_operator_resources" {
  access_group_id = ibm_iam_access_group.application2.id
  roles           = ["Operator"]

  for_each = local.is_network_and_instance_service_types
  resources {
    service = "is"
    attributes = {
      "${each.key}" = each.value
    }
    resource_group_id = ibm_resource_group.application2.id
  }
}
resource "ibm_iam_access_group_policy" "application2_is_instance_resources" {
  access_group_id = ibm_iam_access_group.application2.id
  roles           = ["Editor"]

  for_each = local.is_instance_service_types
  resources {
    service = "is"
    attributes = {
      "${each.key}" = each.value
    }
    resource_group_id = ibm_resource_group.application2.id
  }
}

# -----------------------------------
# application and shared groups both sharing the ssh key - a little weird perhaps
data ibm_is_ssh_key "ssh_key" {
  name = var.ssh_key_name
}
resource "ibm_iam_access_group_policy" "shared_is_key_pfq" {
  for_each        = { shared = ibm_iam_access_group.shared.id, application1 = ibm_iam_access_group.application1.id, application2 = ibm_iam_access_group.application2.id }
  access_group_id = each.value
  roles           = ["Operator"]

  resources {
    service = "is"
    attributes = {
      "keyId" = data.ibm_is_ssh_key.ssh_key.id
    }
  }
}
