packer {
  required_version = ">= 1.5.0"

  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

# Variable definitions
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

variable "aws_ami_name" {
  description = "Name of the AMI to create"
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

variable "artifact_path" {
  description = "Path to the application artifact (e.g., webapp.zip) to be copied into the AMI"
  type        = string
}

# Source block for AWS AMI creation
source "amazon-ebs" "ubuntu" {
  profile       = var.aws_profile
  region        = var.aws_region
  ami_name      = var.aws_ami_name
  instance_type = var.aws_instance_type
  vpc_id        = var.aws_vpc_id
  subnet_id     = var.aws_subnet_id

  # Use the latest Ubuntu 22.04 LTS AMI
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
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

# Build block with provisioners for setting up PostgreSQL, creating a user, copying artifacts, and setting up the systemd service
build {
  sources = ["source.amazon-ebs.ubuntu"]

  # Step 1: Install PostgreSQL
  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y wget ca-certificates",
      # Add PostgreSQL repository and install PostgreSQL
      "wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -",
      "sudo sh -c 'echo \"deb http://apt.postgresql.org/pub/repos/apt jammy-pgdg main\" > /etc/apt/sources.list.d/pgdg.list'",
      "sudo apt-get update",
      "sudo apt-get install -y postgresql postgresql-contrib",
      # Enable and start PostgreSQL service
      "sudo systemctl enable postgresql",
      "sudo systemctl start postgresql"
    ]
  }

  # Step 2: Create a non-login user and group
  provisioner "shell" {
    inline = [
      "sudo groupadd -r csye6225",
      "sudo useradd -r -g csye6225 -s /usr/sbin/nologin csye6225"
    ]
  }

  # Step 3: Copy the application artifact into the image
  provisioner "file" {
    source      = var.artifact_path
    destination = "/opt/webapp/webapp.zip"  # Destination on the AMI
  }

  # Step 4: Extract the application artifact, set ownership, and install dependencies
  provisioner "shell" {
    inline = [
      "sudo mkdir -p /opt/webapp",
      "sudo unzip /opt/webapp/webapp.zip -d /opt/webapp",
      "sudo chown -R csye6225:csye6225 /opt/webapp",  # Set ownership to csye6225 user and group
      "sudo rm /opt/webapp/webapp.zip",  # Remove the zip after extraction
      # Install any required dependencies
      "cd /opt/webapp && sudo -u csye6225 npm install"  # Adjust if your app uses different dependencies
    ]
  }

  # Step 5: Copy the systemd service file to /etc/systemd/system
  provisioner "file" {
    source      = "./myapp.service"  # Path to your systemd service file
    destination = "/etc/systemd/system/myapp.service"
  }

  # Step 6: Enable the service and reload the systemd daemon
  provisioner "shell" {
    inline = [
      "sudo systemctl daemon-reload",
      "sudo systemctl enable myapp",
      "sudo systemctl start myapp"
    ]
  }
}