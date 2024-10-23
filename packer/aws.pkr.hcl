packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Define variables for AWS and database configurations
variable "aws_profile" {
  type = string
}

variable "aws_region" {
  description = "AWS region where the AMI will be created"
  type        = string
}

variable "aws_instance_type" {
  description = "Instance type to use for building the AMI"
  type        = string
}

variable "aws_source_ami" {
  description = "Source AMI to use for building the custom image"
  type        = string
}

variable "aws_vpc_id" {
  description = "VPC ID where the build instance will run"
  type        = string

}

variable "aws_subnet_id" {
  description = "Subnet ID within the VPC where the build instance will run"
  type        = string
}

variable "volume_size" {
  description = "Size of the root volume in GB"
  type        = number
}

# Database configuration variables (from secrets)
variable "DB_USER" {
  type = string
}

variable "DB_PASSWORD" {
  type = string
}

variable "DB_NAME" {
  type = string
}

variable "DB_PORT" {
  type = string
}

variable "aws_dev_user" {
  description = "AWS Account ID for the dev account where the AMI will be created"
  type        = string
}

variable "aws_demo_user" {
  description = "AWS Account ID for the demo account where the AMI should be shared."
  type        = string
}

# Define the source for AWS Amazon AMI
source "amazon-ebs" "ubuntu" {
  profile       = var.aws_profile
  region        = var.aws_region
  ami_name      = "ubuntuAWS-${formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())}"
  instance_type = var.aws_instance_type
  vpc_id        = var.aws_vpc_id
  subnet_id     = var.aws_subnet_id
  ami_users     = [var.aws_dev_user, var.aws_demo_user]

  # Use the latest Ubuntu 24.04 LTS AMI
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"] # Canonical ID for Ubuntu
  }

  ssh_username = "ubuntu"

  ami_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = var.volume_size
    delete_on_termination = true
    volume_type           = "gp2"
  }
}

# Build section with provisioners
build {
  sources = [
    "source.amazon-ebs.ubuntu"
  ]

  # Upload webapp.zip
  provisioner "file" {
    source      = "./webapp.zip"
    destination = "/tmp/webapp.zip"
  }

  # Provision systemd service file
  provisioner "file" {
    source      = "./packer/csye6225.service"
    destination = "/tmp/csye6225.service"
  }

  provisioner "file" {
    source      = "./.env"
    destination = "/tmp/.env"
  }


  # Move service file and reload systemd daemon
  provisioner "shell" {
    inline = [
      "set -e",
      "sudo mv /tmp/csye6225.service /etc/systemd/system/csye6225.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable csye6225.service"
    ]
  }

  # Install Node.js, PostgreSQL, and unzip the webapp
  provisioner "shell" {
    inline = [
      "export DEBIAN_FRONTEND=noninteractive",
      "sudo apt-get clean",
      "sudo apt-get update -y && sudo apt-get upgrade -y",
      "sudo apt-get install -y unzip",
      "curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -",
      "sudo apt-get install -y nodejs",
      "sudo groupadd csye6225",
      "sudo useradd -s /usr/sbin/nologin -g csye6225 -d /var/csye6225 -m csye6225",
      "sudo apt-get install -y postgresql postgresql-contrib",
      "sudo systemctl enable postgresql",
      "sudo systemctl start postgresql",
      "sudo mkdir -p /var/applications/webapp",
      "echo test1",
      "sudo unzip /tmp/webapp.zip -d /var/applications/webapp",
      "sudo chown -R csye6225:csye6225 /var/applications/webapp",
      "echo test2",
      "sudo npm install --prefix /var/applications/webapp/"
    ]
  }

  Provision PostgreSQL configuration using environment variables
  provisioner "shell" {
    inline = [
      "sudo -u postgres psql -tc \"SELECT 1 FROM pg_roles WHERE rolname='${var.DB_USER}';\" | grep -q 1 || sudo -u postgres psql -c \"CREATE USER ${var.DB_USER} WITH PASSWORD '${var.DB_PASSWORD}';\"",
      "sudo -u postgres psql -tc \"SELECT 1 FROM pg_database WHERE datname='${var.DB_NAME}';\" | grep -q 1 || sudo -u postgres psql -c \"CREATE DATABASE ${var.DB_NAME} OWNER ${var.DB_USER};\""
    ]
  }



  # Move the environment file to the correct location
  provisioner "shell" {
    inline = [
      "sudo mv /tmp/.env /var/applications/webapp/.env",
      "sudo chown csye6225:csye6225 /var/applications/webapp/"
    ]
  }

  # Start the Node.js service
  provisioner "shell" {
    inline = [
      "sudo systemctl start csye6225.service",
      "sudo systemctl status csye6225.service"
    ]
  }
}