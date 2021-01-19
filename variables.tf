variable "ami_id" {
  type    = string
  default = null
}

variable "type" {
  type    = string
  default = "t2.micro"
}

variable "aws_region" {
  default = "us-west-2"
}

variable "aws_profile" {
  default = "default"
}

variable "private_key_path" {
  default = "~/.ssh/id_rsa"
}

variable "public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

variable "deployer_key_name" {
  default = "default"
}

variable "ssh_user" {
  default = "ubuntu"
}

## VAULT BASH CONFIG

variable "vault_version" {
  default = "1.6.0"
}

