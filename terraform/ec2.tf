resource "aws_instance" "bastion" {
  ami                    = "ami-08f78cb3cc8a4578e" # Amazon Linux
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public_b.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = aws_key_pair.bastion_key_pair.key_name
  tags = {
    Name = "bastion-host"
  }
  depends_on = [
    aws_subnet.public_b,
    aws_security_group.bastion_sg,
    aws_key_pair.bastion_key_pair
  ]
  provisioner "file" {
    source      = "/Users/shravanchandraparikipandla/Documents/repo/yolo-test/bastion_access_key.pem"
    destination = "/home/${var.user}/.ssh/bastion_access_key"
    connection {
      type        = "ssh"
      user        = var.user
      private_key = tls_private_key.bastion_ssh_key.private_key_pem
      host        = self.public_ip
    }
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.user
      private_key = tls_private_key.bastion_ssh_key.private_key_pem
      host        = self.public_ip
      timeout     = "5m"
    }
    inline = [
      "sudo yum update -y",                    # Update the system first (for RedHat-based systems)
      "sudo yum install -y epel-release",      # Install EPEL repository if not already installed
      "sudo yum install -y ansible",           # Install Ansible
      "ansible-galaxy collection install community.docker --force", # Install the docker community
      "ansible-galaxy collection install community.aws --force",    # Install the cloudwatch aws community
      "sudo yum install -y python",             # Install python
      "chmod 600 /home/${var.user}/.ssh/bastion_access_key"
    ]
  }
}

resource "aws_instance" "private" {
  count          = 3
  ami            = "ami-08f78cb3cc8a4578e" # Amazon Linux
  instance_type  = "t3.micro"
  subnet_id      = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.private_sg.id] # Use the private security group
  iam_instance_profile   = aws_iam_instance_profile.ec2_cw_profile.name # For CloudWatch access
  key_name       = aws_key_pair.bastion_key_pair.key_name # Use the bastion key for initial access
  tags = {
    Name = "private-instance-${count.index + 1}"
  }
  user_data = <<-EOF
    #!/bin/bash
    # Set hostname
    hostname private-instance-${count.index + 1}
    # Add Bastion's Public Key for passwordless access from the bastion
    mkdir -p /home/${var.user}/.ssh
    chmod 700 /home/${var.user}/.ssh
    echo "${tls_private_key.bastion_ssh_key.public_key_openssh}" >> /home/${var.user}/.ssh/authorized_keys
    chmod 600 /home/${var.user}/.ssh/authorized_keys
    chown -R ${var.user}:${var.user} /home/${var.user}/.ssh
    # Install the CloudWatch Agent (for Docker logs)
    sudo yum update -y
    sudo yum install -y amazon-cloudwatch-agent
EOF
  depends_on = [
    aws_subnet.private_a,
    aws_security_group.private_sg,
    aws_iam_instance_profile.ec2_cw_profile,
    aws_key_pair.bastion_key_pair,
    aws_instance.bastion
  ]
}

# fetch the hosts file
resource "local_file" "hosts_file" {
  filename = "/Users/shravanchandraparikipandla/Documents/repo/yolo-test/hosts"
  content = <<-EOT
    [bastion]
    bastion ansible_host=${aws_instance.bastion.public_ip} ansible_user=${var.user} ansible_private_key=/home/${var.user}/.ssh/bastion_access_key

    [nginx-servers]
    private1 ansible_host=${aws_instance.private[0].private_ip} ansible_user=${var.user} ansible_private_key=/home/${var.user}/.ssh/bastion_access_key server_id=1
    private2 ansible_host=${aws_instance.private[1].private_ip} ansible_user=${var.user} ansible_private_key=/home/${var.user}/.ssh/bastion_access_key server_id=2
    private3 ansible_host=${aws_instance.private[2].private_ip} ansible_user=${var.user} ansible_private_key=/home/${var.user}/.ssh/bastion_access_key server_id=3
  EOT
  depends_on = [aws_instance.bastion, aws_instance.private]
}

# Transfer ansible.cfg and hosts file to bastion
resource "null_resource" "copy_ansible_config" {
  provisioner "file" {
    source      = "/Users/shravanchandraparikipandla/Documents/repo/yolo-test/ansible/ansible.cfg"
    destination = "/tmp/ansible.cfg"
    connection {
      type        = "ssh"
      user        = var.user
      private_key = tls_private_key.bastion_ssh_key.private_key_pem
      host        = aws_instance.bastion.public_ip
    }
  }
  provisioner "file" {
    source      = "/Users/shravanchandraparikipandla/Documents/repo/yolo-test/hosts"
    destination = "/tmp/hosts"
    connection {
      type        = "ssh"
      user        = var.user
      private_key = tls_private_key.bastion_ssh_key.private_key_pem
      host        = aws_instance.bastion.public_ip
    }
  }
    provisioner "file" {
    source      = "/Users/shravanchandraparikipandla/Documents/repo/yolo-test/ansible"
    destination = "/tmp/ansible"
    connection {
      type        = "ssh"
      user        = var.user
      private_key = tls_private_key.bastion_ssh_key.private_key_pem
      host        = aws_instance.bastion.public_ip
    }
  }
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.user
      private_key = tls_private_key.bastion_ssh_key.private_key_pem
      host        = aws_instance.bastion.public_ip
    }
    inline = [
      "sudo chmod 755 /etc/ansible",
      "sudo mv /tmp/ansible.cfg /etc/ansible/",
      "export ANSIBLE_CONFIG=/etc/ansible/ansible.cfg",
      "sudo chmod 644 /etc/ansible/ansible.cfg",
      "sudo chown ${var.user}:${var.user} /etc/ansible/ansible.cfg",
      "sudo mv /tmp/hosts /etc/ansible/",
      "sudo chmod 644 /etc/ansible/hosts",
      "sudo chown ${var.user}:${var.user} /etc/ansible/hosts",
      "sudo mv /tmp/ansible/* /etc/ansible/roles",
      "sudo chown -R ${var.user}:${var.user} /etc/ansible/roles"
    ]
  }
  depends_on = [local_file.hosts_file, aws_instance.bastion]
}
