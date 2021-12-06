terraform {
  required_version = ">= 1.0.11"
  required_providers {
    ibm = {
      source = "IBM-Cloud/ibm"
      version = ">= 1.36.0"
    }
  }
}
