# AWS VAULT

EC2 instance for Vault server with File backend in AWS

## Requirements

To start, enter your AWS access keys with aws CLI.

## Usage
For this instance we use Terraform to build infrastructure

### Environment

```sh
$ cp sample.definitions.tfvars definitions.tfvars #change values
```

### Terraform


```sh
## Start
$ terraform init

## Plan
$ terraform plan -var-file="definitions.tfvars"

## Apply
$ terraform apply -var-file="definitions.tfvars" 

## Destroy
$ terraform destroy -var-file="definitions.tfvars" --auto-approve
```

Note: You can use `--auto-approve`

