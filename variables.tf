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

variable "vault_kv_engine" {
  default = "1"
}

variable "vault_secrets_path" {
  default = "v1"
}

variable "vault_auth_user" {
  type    = string
  default = null
}

variable "vault_auth_pass" {
  type    = string
  default = null
}

variable "vault_addr" {
  default = "http://0.0.0.0:8200"
}
