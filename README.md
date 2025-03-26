# Learn Terraform - Provision an EKS Cluster

This repo is a companion repo to the [Provision an EKS Cluster tutorial](https://developer.hashicorp.com/terraform/tutorials/kubernetes/eks), containing
Terraform configuration files to provision an EKS cluster on AWS.

## Getting started

```bash
# Modify the contents of the terraform.tfvars file to adjust the infrastructure as needed
# Run the following commands to initialize and stand up your infrastructure

# First initialize your SSO for AWS. Run the following command and setup your project
aws configure sso --profile adios-tailscale-poc
tofu init
tofu apply
```

## Accessing your cluster

## Finishing up

```bash
# Once you've completed your testing and no longer need your infrastructure you'll need to
# tear down your infrastructure
tofu destroy
```
