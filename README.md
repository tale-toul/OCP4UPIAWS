# UPI instalation on AWS

## Table of contents

## Introduction

This project contains the necesary elements to deploy an Openshift 4 cluster on AWS using the UPI installation method

## Installation instructions

This instructions follow the ones provided in [Installing a cluster on user-provisioned infrastructure in AWS by using CloudFormation templates:](https://docs.openshift.com/container-platform/4.4/installing/installing_aws/installing-aws-user-infra.html)

1. [Download the installation program](https://docs.openshift.com/container-platform/4.4/installing/installing_aws/installing-aws-user-infra.html#installation-obtaining-installer_installing-aws-user-infra)

1. [Create an ssh key pair](https://docs.openshift.com/container-platform/4.4/installing/installing_aws/installing-aws-user-infra.html#ssh-agent-using_installing-aws-user-infra).- This key will be installed on every node in the cluster and will allow pawordless connections to those machines.

```shell
 $ ssh-keygen -o -t rsa -f upi-ssh -N "" -b 4096
```

The previous command will produce two files: upi-ssh and upi-ssh.pub.  Copy them both to the directory **~/.ssh** so they can be used in the nex step:

```shell
$ cp upi-ssh* ~/.ssh
```

1. [Create the **install-config.yaml** file](https://docs.openshift.com/container-platform/4.4/installing/installing_aws/installing-aws-user-infra.html#installation-generate-aws-user-infra-install-config_installing-aws-user-infra).- This file is the configuration file that will describe the cluster to be installed, and it is fed to the installer program.  An easy way to create the file is by using the install program with the options "create install-config" and answer the questions asked.  The option **--dir** is followed by a directory name, it is best to use a new empty directory to avoid conflic with any other installation, if the directory does not exist the installation program will create it:
 The base domain for the cluster must exist before running the command, otherwise the installer program will not get pass that question.

```shell
 $ $ ./openshift-install create install-config --dir clovercluster
? SSH Public Key /home/jjerezro/.ssh/upi-ssh.pub
? Platform aws
INFO Credentials loaded from the "default" profile in file "/home/jjerezro/.aws/credentials" 
? Region eu-west-3
? Base Domain lili  [Use arrows to move, enter to select, type to filter, ? for more help]
FATAL failed to fetch Install Config: failed to fetch dependency of "Install Config": failed to generate asset "Base Domain": failed UserInput for base domain: interrupt 
[jjerezro@jjerezro OCP4AWSUPI]$ ./openshift-install create install-config --dir clover
? SSH Public Key /home/jjerezro/.ssh/upi-ssh.pub
? Platform aws
INFO Credentials loaded from the "default" profile in file "/home/jjerezro/.aws/credentials" 
? Region eu-west-3
? Base Domain tale.rhcee.support
? Cluster Name clover
? Pull Secret [? for help] **************************************************************
```
The previous command will create the directory _clovercluster_ if this does not already exist, and will put the file **install-config.yaml** inside the directory.

1. Edit the **install-config.yaml** file and se the number of worker replicas to 0.  Make any other changes to the file required for the installation:

```yaml
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform: {}
  replicas: 0
```

1. Make a backup copy of the **install-config.yaml** file, because the file will be destroyed as part of the installation process:

1. Create the Kubernetes manifests for the cluster

```shell
 $ $ ./openshift-install create manifests --dir clover/
INFO Credentials loaded from the "default" profile in file "/home/jjerezro/.aws/credentials" 
INFO Consuming Install Config from target directory 
WARNING Making control-plane schedulable by setting MastersSchedulable to true for Scheduler cluster settings
```
1. Remove the Kubernetes manifest files that define the control plane and worker machines. By removing these files, you prevent the cluster from automatically generating these machines.

```shell
$ rm clover/openshift/99_openshift-cluster-api_master-machines-*.yaml
$ rm clover/openshift/99_openshift-cluster-api_worker-machineset-*.yaml
```
1. Edit the file **cluster-scheduler-02-config.yml** in the manifests directory and set the parameter **mastersSchedulable** to **false** to prevent pods from being scheduled on the master machines:

```yaml
spec:
  mastersSchedulable: false
```

1. Create the ignition files.  

```shell
$ ./openshift-install create ignition-configs --dir clover/
INFO Consuming OpenShift Install (Manifests) from target directory 
INFO Consuming Master Machines from target directory 
INFO Consuming Worker Machines from target directory 
INFO Consuming Openshift Manifests from target directory 
INFO Consuming Common Manifests from target directory
```

1. Get the infrastructure name assigned by the installer, this cosists of the clustername followed by a random short string.  This name will be used later as the base of other components names: 

```shell
$ cat clover/metadata.json |jq -r .infraID
clover-ltwcq
```

The value returned must be used with the variable **infra_name** when running terraform


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

### Terraform initialization

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

### Creating the infrastructure

Get the value for the variable **infra_name** as explained above:

```shell
$ cat clover/metadata.json |jq -r .infraID
clover-ltwcq
```

Get the Hosted Zone ID for the Route53 zone that you will use as external public zone, and was specified in the intall-config.yaml file.  

This information can be obtained from the AWS web interface, and looks like this example:

```
Hosted Zone ID: Z00659431CO1O47AE0285
```
The ID will be used with the variable **dns_domain_ID**


Review the rest of variable in the file input-vars.tf, then go to the Terraform directory and run a command like:

```shell
$ terraform apply -var="region_name=eu-west-3" -var="cluster_name=clover" -var="infra_name=clover-ltwcq" -var="dns_domain_ID=Z00659431CO1O47AE0285"
```

## References

[0] [Installation and update](https://docs.openshift.com/container-platform/4.4/architecture/architecture-installation.html#architecture-installation)
[1] [Installing a cluster on user-provisioned infrastructure in AWS by using CloudFormation templates:](https://docs.openshift.com/container-platform/4.4/installing/installing_aws/installing-aws-user-infra.html)

## Pending

* The external DNS zone must exist prior to running terraform because it is required by the openshift installer program, therefore it cannot be created later by terraform.  It could be created by an idependent terraform module that is run before the openshift installer program though.

* The bootstrap instance and related resources (S3 bucket for boostrap ignition file), creation should be done in an independent module, so they can be easily deleted after installation.

* Add user defined tags to the install-config.yaml file
