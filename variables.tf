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

# note changing image to a different linux (ubuntu to centos for example) requires changing
# user_data for the instances as well.  Changing versions of ubuntu will likely work
variable image {
  # default = "ibm-centos-stream-9-amd64-8"
  default = "ibm-ubuntu-20-04-2-minimal-amd64-1"
}
