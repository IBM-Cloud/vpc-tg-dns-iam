resource "ibm_resource_group" "admin" {
  name = "${var.basename}-admin"
}

# ---------------- secrets manager instance
resource "ibm_resource_instance" "secrets_manager" {
  name              = "secrets-manager"
  service           = "secrets-manager"
  plan              = "lite"
  location          = var.ibm_region
  resource_group_id = ibm_resource_group.admin.id
}
# ---------------- 
# service id with policies needed by the secrets manager iam_credentials engine
# in the GUI this is created in the settings api
resource "ibm_iam_service_id" "sm_iam_engine" {
  name = "sm-iam-engine"
}

resource "ibm_iam_service_policy" "iam_groups_editor" {
  iam_service_id = ibm_iam_service_id.sm_iam_engine.id
  roles        = ["Editor"]
  resources {
    service = "iam-groups"
  }
}

resource "ibm_iam_service_policy" "iam_identity_operator" {
  iam_service_id = ibm_iam_service_id.sm_iam_engine.id
  roles        = ["Operator"]
  resources {
    service = "iam-identity"
  }
}
# ---------------- secrets manager configuration
locals {
  sm_service_api = "https://${ibm_resource_instance.secrets_manager.guid}.${var.ibm_region}.secrets-manager.appdomain.cloud/api"
  sm_vault_api = "https://${ibm_resource_instance.secrets_manager.guid}.${var.ibm_region}.secrets-manager.appdomain.cloud"
  sm_swagger_api = "https://${ibm_resource_instance.secrets_manager.guid}.${var.ibm_region}.secrets-manager.appdomain.cloud/swagger-ui/"
}


# ---------------- network
resource "ibm_iam_access_group" "network_admin" {
  name        = "${var.basename}-network-admin"
  description = "network_admin administrators"
}
resource "ibm_iam_service_id" "network_admin" {
  name        = "${var.basename}-network-admin"
  description = "network_admin service id"
}
resource "ibm_iam_access_group_members" "network_admin" {
  access_group_id = ibm_iam_access_group.network_admin.id
  iam_service_ids = [ibm_iam_service_id.network_admin.id]
}

resource "null_resource" "secrets_manager_settings" {
  triggers = {
    path_module = path.module
    script = "${path.module}/secretsmanager/secrets_manager_settings.sh"
    SERVICE_ID_SM_IAM_ENGINE = ibm_iam_service_id.sm_iam_engine.id
    SERVICE_API = local.sm_service_api
    ADMIN_API_KEY = var.ibmcloud_api_key
  }
  provisioner "local-exec" {
    command = <<-EOS
      path_module=path.module \
      SERVICE_ID_SM_IAM_ENGINE=${self.triggers.SERVICE_ID_SM_IAM_ENGINE} \
      SERVICE_API=${self.triggers.SERVICE_API} \
      ADMIN_API_KEY=${self.triggers.ADMIN_API_KEY} \
      ${self.triggers.script} create
    EOS
  }
}

locals {
  secrets_group_id_network_file = "${path.module}/secrets_group_id_network.txt"
  secrets_id_network_file = "${path.module}/secrets_id_network.txt"
  secret_group_name = "network_admin"
  secret_name = "network_resources"
}

# secrets manager
resource "null_resource" "network_secrets" {
  depends_on = [null_resource.secrets_manager_settings]
  triggers = {
    path_module = path.module
    script = "${path.module}/secretsmanager/secrets_manager_group.sh"
    ADMIN_API_KEY = var.ibmcloud_api_key
    SECRET_GROUP_NAME = local.secret_group_name
    SECRET_NAME = local.secret_name
    IAM_ACCESS_GROUP_IDS = ibm_iam_access_group.network.id # comma separated list of access group ids
    VAULT_ADDR = local.sm_vault_api
    SECRETS_GROUP_FILE = local.secrets_group_id_network_file
    SECRETS_FILE = local.secrets_id_network_file
  }
  provisioner "local-exec" {
    command = <<-EOS
      ADMIN_API_KEY=${self.triggers.ADMIN_API_KEY} \
      IAM_ACCESS_GROUP_IDS="${self.triggers.IAM_ACCESS_GROUP_IDS}" \
      SECRET_GROUP_NAME=${self.triggers.SECRET_GROUP_NAME} \
      SECRET_NAME=${self.triggers.SECRET_NAME} \
      VAULT_ADDR=${self.triggers.VAULT_ADDR} \
      SECRETS_GROUP_FILE=${self.triggers.SECRETS_GROUP_FILE } \
      SECRETS_FILE=${self.triggers.SECRETS_FILE } \
      ${self.triggers.script} create
    EOS
  }
  provisioner "local-exec" {
    when = destroy
    command = <<-EOS
      ADMIN_API_KEY=${self.triggers.ADMIN_API_KEY} \
      IAM_ACCESS_GROUP_IDS="${self.triggers.IAM_ACCESS_GROUP_IDS}" \
      SECRET_GROUP_NAME=${self.triggers.SECRET_GROUP_NAME} \
      SECRET_NAME=${self.triggers.SECRET_NAME} \
      VAULT_ADDR=${self.triggers.VAULT_ADDR} \
      SECRETS_GROUP_FILE=${self.triggers.SECRETS_GROUP_FILE } \
      ${self.triggers.path_module}/secretsmanager/secrets_manager_group.sh destroy
    EOS
  }
}
data "local_file" "secrets_group_id_network_file" {
  filename = local.secrets_group_id_network_file
  depends_on = [null_resource.network_secrets]
}
data "local_file" "secrets_id_network_file" {
  filename = local.secrets_id_network_file
  depends_on = [null_resource.network_secrets]
}

# viewer access to resource group
resource "ibm_iam_access_group_policy" "resource_group_app_viewer" {
  access_group_id = ibm_iam_access_group.network_admin.id
  roles           = ["Viewer"]
  resources {
    resource_type = "resource-group"
    resource      = ibm_resource_group.admin.id
  }
}
# vault login
# TODO this is a bug, writer permissions should not be required for the entire instance
resource "ibm_iam_access_group_policy" "secrets_manager_reader" {
  access_group_id = ibm_iam_access_group.network_admin.id
  roles           = ["Writer"]
  resources {
    service = "secrets-manager"
    resource_instance_id = ibm_resource_instance.secrets_manager.guid
  }
}

# read access to the secret-group to get
# todo write access to the group is currently required
resource "ibm_iam_access_group_policy" "network_admin" {
  access_group_id = ibm_iam_access_group.network_admin.id
  roles           = ["Writer"]
  resources {
    service = "secrets-manager"
    resource_instance_id = ibm_resource_instance.secrets_manager.guid
    resource_type = "secret-group"
    resource = data.local_file.secrets_group_id_network_file.content # prod-data secrets group
  }
}

output VAULT_ADDR {
    value = local.sm_vault_api
}
output SECRETS_MANAGER_GROUP_ID_NETWORK {
    value = data.local_file.secrets_group_id_network_file.content
}
output SECRETS_MANAGER_SECRET_ID_NETWORK {
    value = data.local_file.secrets_id_network_file.content
}
