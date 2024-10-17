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

# Define the source for AWS Amazon AMI
source "amazon-ebs" "ubuntu" {
  profile       = var.aws_profile
  region        = var.aws_region
  ami_name      = "ubuntu-24.04-${formatdate("YYYY-MM-DD-hh-mm-ss", timestamp())}"
  instance_type = var.aws_instance_type
  vpc_id        = var.aws_vpc_id
  subnet_id     = var.aws_subnet_id

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

  # Move service file and reload systemd daemon
  provisioner "shell" {
    inline = [
      "sudo mv /tmp/csye6225.service /etc/systemd/system/csye6225.service",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable csye6225.service"
    ]
  }

  # Install Node.js, PostgreSQL, and unzip the webapp
  provisioner "shell" {
    inline = [
      "sudo apt-get update -y && sudo apt-get upgrade -y",
      "curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -",
      "sudo apt-get install -y nodejs",
      "sudo apt-get install -y postgresql postgresql-contrib",
      "sudo systemctl enable postgresql",
      "sudo systemctl start postgresql",
      "sudo mkdir -p /opt/applications/webapp",
      "sudo unzip /tmp/webapp.zip -d /opt/applications/webapp",
      "sudo chown -R csye6225:csye6225 /opt/applications/webapp",
      "sudo npm install --prefix /opt/applications/webapp"
    ]
  }

  # Provision PostgreSQL configuration using environment variables
  provisioner "shell" {
    inline = [
      "sudo -u postgres psql -tc \"SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}';\" | grep -q 1 || sudo -u postgres psql -c \"CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';\"",
      "sudo -u postgres psql -tc \"SELECT 1 FROM pg_database WHERE datname='${DB_NAME}';\" | grep -q 1 || sudo -u postgres psql -c \"CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};\""
    ]
  }

  # Transfer environment file from local machine to server
  provisioner "file" {
    source      = "./environment/development.env"
    destination = "/tmp/development.env"
  }

  # Copy the environment file to the correct location
  provisioner "shell" {
    inline = [
      "sudo mv /tmp/development.env /opt/applications/webapp/.env"
    ]
  }

  # Move the environment file to the correct location
  provisioner "shell" {
    inline = [
      "sudo mv /tmp/.env /opt/applications/webapp/.env",
      "sudo chown csye6225:csye6225 /opt/applications/webapp/.env"
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
