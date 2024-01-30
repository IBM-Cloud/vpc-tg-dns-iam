variable remote_ip {}

#-----------------------------------------------------------------------------------------
# The user_data application is shared by all of the VSIs.  It is a hello world app contained in two files
# app.js - node app
# a-app.service - systemctl service that wraps the app.js
#
# The string will be connected to a remote app via the remote_ip variable
locals {
  shared_app_user_data_centos = <<-EOS
    #!/bin/sh
    curl -sL https://rpm.nodesource.com/setup_20.x | sudo bash -
    yum install nodejs -y
    cat > /app.js << 'EOF'
    ${file("${path.module}/app.js")}
    EOF
    cat > /lib/systemd/system/a-app.service << 'EOF'
    ${replace(file("${path.module}/a-app.service"), "NODE", "/usr/bin/node")}
    EOF
    systemctl daemon-reload
    systemctl start a-app
EOS

  shared_app_user_data_awslinux2 = <<-EOS
    #!/bin/bash
    curl -sL https://rpm.nodesource.com/setup_20.x | bash -
    yum install nodejs -y
    cat > /app.js << 'EOF'
    ${file("${path.module}/app.js")}
    EOF
    cat > /lib/systemd/system/a-app.service << 'EOF'
    ${replace(file("${path.module}/a-app.service"), "NODE", "/bin/node")}
    EOF
    systemctl daemon-reload
    systemctl start a-app
EOS

  shared_app_user_data_ubuntu = <<-EOS
    #!/bin/bash
    set -x
    while ! apt update -y; do
      sleep 10
    done
    apt install -y nodejs
    cat > /app.js << 'EOF'
    ${file("${path.module}/app.js")}
    EOF
    cat > /lib/systemd/system/a-app.service << 'EOF'
    ${replace(file("${path.module}/a-app.service"), "NODE", "/bin/node")}
    EOF
    systemctl daemon-reload
    systemctl start a-app
EOS
}

output user_data_centos {
  value = replace(local.shared_app_user_data_centos, "REMOTE_IP", var.remote_ip)
}
output user_data_awslinux2 {
  value = replace(local.shared_app_user_data_awslinux2, "REMOTE_IP", var.remote_ip)
}
output user_data_ubuntu {
  value = replace(local.shared_app_user_data_ubuntu, "REMOTE_IP", var.remote_ip)
}
