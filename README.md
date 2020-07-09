# UPI instalation on AWS

## Table of contents

## Introduction

This project contains the necesary elements to deploy an Openshift 4 cluster on AWS using the UPI installation method

## Deploying the infrastructure with terraform

Terraform is used to create the infrastructure components of the VPC, some of these components can be adjusted via the use of variables defined in the file _Terrafomr/input-vars.tf_, like if a proxy is used to manage connections from the cluster to the Internet, the name of the cluster, the name of the DNS subdomain, etc.

### Terraform installation

The installation of terraform is as simple as downloading a zip compiled binary package for your operating system and architecture from:

[https://www.terraform.io/downloads.html](https://www.terraform.io/downloads.html)

Then unzip the file:

```shell
# unzip terraform_0.11.8_linux_amd64.zip 
Archive:  terraform_0.11.8_linux_amd64.zip
inflating: terraform
```
Place the binary somewhere in your path:

```shell
# cp terraform /usr/local/bin
```
Check that it is working:

```shell
# terraform --version
```

### First run

After creating the first vesrion of the manifest files, for that run the following command in the directory where the manifest files are:

```shell
# terraform init
Initializing the backend...

Initializing provider plugins...
- Checking for available provider plugins...
- Downloading plugin for provider "random" (hashicorp/random) 2.3.0...
- Downloading plugin for provider "aws" (hashicorp/aws) 2.69.0...

Terraform has been successfully initialized!
```


## References

[0] [Installation and update](https://docs.openshift.com/container-platform/4.4/architecture/architecture-installation.html#architecture-installation)
[1] [Installing a cluster on user-provisioned infrastructure in AWS by using CloudFormation templates:](https://docs.openshift.com/container-platform/4.4/installing/installing_aws/installing-aws-user-infra.html)

