variable ibmcloud_api_key {}
variable ssh_key_name {}
variable basename {}
variable ibm_region {}
variable transit_gateway {
  default = false
}
variable shared_lb {
  default = false
}

variable profile {
  default = "cx2-2x4"
}
variable centos_minimal {
  default = "ibm-centos-7-6-minimal-amd64-2"
}
