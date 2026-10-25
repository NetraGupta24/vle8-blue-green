terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_instance" "vle8_existing" {
  ami                    = "ami-094adff9b24048c5c"
  instance_type          = "t3.small"
  subnet_id              = "subnet-0d64ff740f991af6b"
  vpc_security_group_ids = ["sg-0f7907fc2f42bcf81"]
  key_name               = "vle8-key"

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "vle8-blue-green-lab"
  }

  lifecycle {
    prevent_destroy = true
  }
}

output "existing_instance_id" {
  value = aws_instance.vle8_existing.id
}

output "existing_instance_type" {
  value = aws_instance.vle8_existing.instance_type
}

output "existing_instance_state" {
  value = aws_instance.vle8_existing.instance_state
}
