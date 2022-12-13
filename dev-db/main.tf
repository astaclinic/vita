resource "aws_lightsail_instance" "vita_db" {
  name              = var.instance_name
  availability_zone = var.instance_availability_zone
  blueprint_id      = var.instance_blueprint_id
  bundle_id         = var.instance_bundle_id
  key_pair_name     = aws_lightsail_key_pair.vita_db_key.name
  user_data         = <<-EOT
  #!/bin/bash
  apt-get -y update

  # add docker repo
  sudo apt-get install -y ca-certificates curl gnupg lsb-release
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  # add hashicorp repo
  wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

  # installation
  sudo apt-get -y update
  sudo apt-get -y install docker-ce docker-ce-cli containerd.io nomad consul python3-pip
  pip install python-nomad

  # remove default config file
  sudo rm /etc/nomad.d/nomad.hcl /etc/consul.d/consul.hcl

  # install cni plugin
  curl -L -o cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/v1.0.0/cni-plugins-linux-$( [ $(uname -m) = aarch64 ] && echo arm64 || echo amd64)"-v1.0.0.tgz
  sudo mkdir -p /opt/cni/bin
  sudo tar -C /opt/cni/bin -xzf cni-plugins.tgz
  EOT
}

resource "aws_lightsail_static_ip" "vita_db_ip" {
  name = "vita_db_ip"
}

resource "aws_lightsail_static_ip_attachment" "vita_db_ip_attach" {
  static_ip_name = aws_lightsail_static_ip.vita_db_ip.id
  instance_name  = aws_lightsail_instance.vita_db.id
}

resource "aws_lightsail_key_pair" "vita_db_key" {
  name = "vita_db_key"
}

resource "local_sensitive_file" "private_key" {
  content         = aws_lightsail_key_pair.vita_db_key.private_key
  filename        = "${path.module}/private.key"
  file_permission = "0400"
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/provisioning/inventory"
  content  = <<-EOT
[${aws_lightsail_instance.vita_db.name}]
${aws_lightsail_static_ip.vita_db_ip.ip_address}
[${aws_lightsail_instance.vita_db.name}:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new'
  EOT
}

resource "null_resource" "lightsail_provisioner" {
  triggers = {
    inventory_hash = filesha256(file(local_file.ansible_inventory.filename))
  }
  provisioner "local-exec" {
    command = <<-EOT
      ansible-playbook -i ${local_file.ansible_inventory.filename} --private-key ${local_sensitive_file.private_key.filename} -u admin ${path.module}/provisioning/playbook.yml --extra-vars '{"datacenter":"apricot","registry_username":"${var.registry_username}", "registry_password":"${var.registry_password}", "mongodb_username":"${var.mongodb_username}", "mongodb_password":"${var.mongodb_password}"}'
    EOT
  }
  depends_on = [
    local_file.ansible_inventory
  ]
}

resource "aws_lightsail_instance_public_ports" "vita_db_ports" {
  instance_name = aws_lightsail_instance.vita_db.name
  port_info {
    protocol  = "tcp"
    from_port = 27017
    to_port   = 27017
  }
  port_info {
    protocol  = "tcp"
    from_port = 22
    to_port   = 22
  }
}

output "ip" {
  value = aws_lightsail_static_ip.vita_db_ip.ip_address
}


