terraform {
  required_providers {
    ibm = ">= 1.10.0"
  }
}

variable ibmcloud_api_key {}
variable ssh_key_name {}
variable basename {}
variable ibm_region {}
variable shared_lb {}
variable transit_gateway {}

# vpc generation 1 not supported at this time, leave at 2
variable generation {
  default = 2
}
variable profile {
    default = {
    "1" = "cc1-2x4"
    "2" = "cx2-2x4"
    }
}
variable centos_minimal {
    default = {
    "1" = "ibm-centos-7-6-minimal-amd64-1"
    "2" = "ibm-centos-7-6-minimal-amd64-2"
    }
}
