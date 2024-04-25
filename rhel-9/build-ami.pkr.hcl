packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebssurrogate" "ubuntu" {
  assume_role {
    role_arn     = "arn:aws:iam::211125334931:role/Packer"
    session_name = "Packer"
  }
  ami_name                = "learn-packer-linux-aws"
  boot_mode               = "uefi"
  instance_type           = "t2.micro"
  region                  = "us-east-2"
  ami_virtualization_type = "hvm"
  source_ami_filter {
    filters = {
      name                = "RHEL-9.3*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
      architecture        = "x86_64"
    }
    most_recent = true
    owners      = ["309956199498"]
  }
  launch_block_device_mappings {
    volume_type           = "gp3"
    device_name           = "/dev/sdb"
    delete_on_termination = true
    snapshot_id           = "snap-08b5d97a2e1b56df9"
  }
  ami_root_device {
    source_device_name    = "/dev/sdb"
    device_name           = "/dev/xvda"
    delete_on_termination = true
    volume_size           = 10
    volume_type           = "gp3"
  }
  ssh_username = "ec2-user"
  uefi_data    = "QU1aTlVFRkni4yd4AAAAAHj5a7fZ94NNtzFB6QBvHSgLPQh1kFZboAN096ljUaNA5GJgmIu8Xb1hsUbN2EQ0pUdeiwuXmylcMYdSH4xO5wzUdM5IazkxMoyOq4/scXVqVjuwCjAlyQFHrQMTV2HDVuuwCQBrnR+wWofj8hGwWpahVOvQaJEqLjcjZuGwu3m0Xz/arx/KtdPo+oiRvT4CfVqAktoJAPbjzLE="
}

build {
  name = "learn-packer"
  sources = [
    "source.amazon-ebssurrogate.ubuntu"
  ]

  provisioner "file" {
    source      = "${path.root}/build_ami.sh"
    destination = "~/build_ami.sh"
  }

  provisioner "file" {
    source      = "${path.root}/cleanup.sh"
    destination = "~/cleanup.sh"
  }

  provisioner "shell" {
    remote_folder = "~"
    inline = [
      "sudo bash ~/build_ami.sh",
      "sudo bash ~/cleanup.sh",
    ]
  }

  post-processors {
    post-processor "manifest" {}
  }
}
