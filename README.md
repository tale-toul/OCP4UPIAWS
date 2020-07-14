# UPI instalation on AWS

## Table of contents

## Introduction

This project contains the necesary elements to deploy an Openshift 4.4 cluster on AWS using the UPI installation method

## Requirements

* An [AWS account](https://aws.amazon.com) with sufficient privileges to create the resources required by Openshift.

* A public DNS domain managed by AWS, to publish the cluster on.  There is a convenient module to create a DNS subdomain in the directory  **ExternalDNSHostedZone**.  If the cluster is private this DNS domain is not required but at the moment this project will not create a private cluster.

* A [Red Hat account](https://cloud.redhat.com) 

* At least 500MB of disk space in the machine where the installation is run from

* [Terraform](https://www.terraform.io/) must be installed in the local machine.
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

## Installation instructions

The installation steps follow the instructions provided at [Installing a cluster on user-provisioned infrastructure in AWS by using CloudFormation templates:](https://docs.openshift.com/container-platform/4.4/installing/installing_aws/installing-aws-user-infra.html), but instead of CloudFormation, Terraform is used to create the resources in AWS.

1. [Download the installation program](https://cloud.redhat.com/openshift/install) for the AWS cloud provider

1. [Download the pull secret](https://cloud.redhat.com/openshift/install) from the same page as the installer.

1. [Create an ssh key pair](https://docs.openshift.com/container-platform/4.4/installing/installing_aws/installing-aws-user-infra.html#ssh-agent-using_installing-aws-user-infra).- This key will be installed on every node in the cluster and will allow pawordless connections to those machines.  This step is not extrictly required for twu reason: 

  1. ssh connections to the cluster instances are not required, quite the contrary they are discourage, but it is a convenient tool in case issues come up during cluster installation.

  1. An already existinig ssh key pair can be used, as long as it is present in the direcotry ~/.ssh

```shell
 $ ssh-keygen -o -t rsa -f upi-ssh -N "" -b 4096
```

The previous command will produce two files: upi-ssh and upi-ssh.pub.  Copy them both to the directory **~/.ssh** so they can be used in the nex step:

```shell
$ cp upi-ssh* ~/.ssh
```

1. [Create the **install-config.yaml** file](https://docs.openshift.com/container-platform/4.4/installing/installing_aws/installing-aws-user-infra.html#installation-generate-aws-user-infra-install-config_installing-aws-user-infra).- This is the configuration file that will describe the cluster to be installed. The easiest way to create the file is by using the install program with the options **"create install-config"** and answer the questions asked.  The option **--dir** is followed by a directory name, it is best to use an empty directory or a non existing one to avoid conflic with any previous installation, if the directory does not exist the installation program will create it:

The command will ask:

* For the ssh keys that will be installed in the EC2 instances
* The platform provider, AWS in this case
* The credentials of the AWS account to use to deploy the resources.  If the file ~/.aws/credentials exists and contains valid credentials, these will be used.
* The AWS region where the cluster will be deployed
* The base DNS domain to use for the cluster public URLs.  This domain must already exist and be managed by AWS.
* A name for the cluster, used as the base for naming the resources, and will be added to the above DNS domain
* The pull secret to download container images from Red Hat.  The pull secret is pasted on the console when the installer asks for it.

```shell
 $ $ ./openshift-install create install-config --dir clover
? SSH Public Key /home/jjerezro/.ssh/upi-ssh.pub
? Platform aws
INFO Credentials loaded from the "default" profile in file "/home/indalpa/.aws/credentials" 
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
The previous command will create the directory _clover_ if it does not already exist, and will put the file **install-config.yaml** inside the directory.

1. Edit the **install-config.yaml** file and set the number of worker replicas to 0.  Make any other changes to the file required for the installation:

```yaml
compute:
- architecture: amd64
  hyperthreading: Enabled
  name: worker
  platform: {}
  replicas: 0
```

1. Make a backup copy of the **install-config.yaml** file, because it will be destroyed as part of the installation process:

1. Create the Kubernetes manifests for the cluster

```shell
 $ ./openshift-install create manifests --dir clover
INFO Credentials loaded from the "default" profile in file "/home/jjerezro/.aws/credentials" 
INFO Consuming Install Config from target directory 
WARNING Making control-plane schedulable by setting MastersSchedulable to true for Scheduler cluster settings
```
1. Remove the Kubernetes manifest files that define the control plane and worker machines. By removing these files, you prevent the cluster from automatically generating these machines.

```shell
$ rm clover/openshift/99_openshift-cluster-api_master-machines-*.yaml
$ rm clover/openshift/99_openshift-cluster-api_worker-machineset-*.yaml
```
1. Edit the file **manifests/cluster-scheduler-02-config.yml**  and set the parameter **mastersSchedulable** to **false** to prevent pods from being scheduled on the master machines:

```yaml
spec:
  mastersSchedulable: false
```

1. Make sure that the tags section in the file **manifests/cluster-dns-02-config.yml** are the same that will later be used by terraform to create the infrastructure, and the public zone id is also the same that will be used by terraform.

```yaml
spec:
  baseDomain: clover.tale.rhcee.support
  privateZone:
    tags:
      Name: clover-qvml2-int
      kubernetes.io/cluster/clover-qvml2: owned
  publicZone:
    id: Z00639231CO3O47AE0285
```

1. Create the ignition files.  

```shell
$ ./openshift-install create ignition-configs --dir clover
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

1. Get the encoded certificate authority to be used by the master instances.  This is the long string located in the master ignition file **master.ign** and looks like this:

`data:text/plain;charset=utf-8;base64,LS0tLS1CRUdJTiBDRVJUSUZJQ0<long string of characters>==`

This long string must be assigned to the variable **master_ign_CA**, this could be done in the command line, but because this string is so cumberson to work with it is easier to add it to the **input-vars.tf** file as a default clause:

variable "master_ign_CA" {
  description = "The Certificate Authority (CA) to be used by the master instances"
  type = string
  default = "data:text/plain;charset=utf-8;base64,LS0tLS1CRUdJTiBDRVJUSUZJQ0<long string of characters>=="
}


## Deploying the infrastructure with terraform

Terraform is used to create the infrastructure components of the VPC, some of these components can be adjusted via the use of variables defined in the file _Terrafomr/input-vars.tf_, like if a proxy is used to manage connections from the cluster to the Internet, the name of the cluster, the name of the DNS subdomain, etc.

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

Define the variable **master_ign_CA** with the base64 definition of the CA certificate that will use master and nodes.

Review the rest of variable in the file input-vars.tf, then go to the Terraform directory and run a command like:

```shell
$ terraform apply -var="region_name=eu-west-3" -var="cluster_name=clover" -var="infra_name=clover-ltwcq" -var="dns_domain_ID=Z00659431CO1O47AE0285"
```
When the infrastructure has been created, run the following command to check on the installationm process:
```shell
$ ./openshift-install wait-for bootstrap-complete --dir=clover --log-level=info
```

The log file for the installation may be usefull, it is located at **clover/.openshift_install.log**

Another way to peek into the installation process is to ssh into the bootstrap instance and run the journalct command:

```shell
$ ssh-agent bash
$ ssh-add ~/.ssh/upi-ssh
$ ssh core@<IP of bootstrap instance>
bootstrap $ journalctl -b -f -u bootkube.service

```


## User data for the instances

Each of the EC2 instance definition for bootstrap, master and nodes need a user data block that will instruct the instance on where to get the ignition file required to do the initial set up of the instance.

The _Boostrap_ instance user data basically contains the URL to get the file **bootstrap.ign** that was generated during the first steps of the installation process.  This file is stored in an S3 bucket that is created by terraform, the **bootstrap.ign** file is copied to the bucket also by terraform.

The URL used to access the file is defined in terraform like: `s3://${aws_s3_bucket.ignition-bucket.id}/bootstrap.ign`  The variable contains the name of the bucket.  The only important consideration here is that the bucket and file exist before the bootstrap instance is created and started, so the following line is added to the bootstrap's definition:
```
  depends_on = [aws_s3_bucket.ignition-bucket]
```

The _Master_ instances user data also contains the URL to download its ignition file, in this case an HTTPS URL is used. The use of a secure TLS connection requires the user data to also contains the CA certificate required to validate the web server's certificate.
The URL for the ignition file is defined like: `https://api-int.${var.cluster_name}.${local.dotless_domain}:22623/config/master`  The variable **${local.dotless_domain}** is defined as `dotless_domain = replace("${data.aws_route53_zone.domain.name}","/.$/","")` this function takes the domain name for the internal hosted zone and removes the last dot in the name, for example for the name **example.com.** the function returns **example.com** without the final dot. This step is required because the hosted zone domain name includes a dot at the end, which renders the URL invalid.  The final URL for a cluster name of clover would be `https://api-int.clover.example.com:22623/config/master`
The Certificate Autority (CA) certificate is stored in the variable **${var.master_ign_CA}**, this variable is defined during the installation steps.
It is import that the DNS record for **api-int** exists before creating the master instance, so the following line is added to the master's definition:

```
  depends_on = [aws_route53_record.api-internal-internal]
```

## References

[0] [Installation and update](https://docs.openshift.com/container-platform/4.4/architecture/architecture-installation.html#architecture-installation)
[1] [Installing a cluster on user-provisioned infrastructure in AWS by using CloudFormation templates:](https://docs.openshift.com/container-platform/4.4/installing/installing_aws/installing-aws-user-infra.html)

## Pending

* The external DNS zone must exist prior to running terraform because it is required by the openshift installer program, therefore it cannot be created later by terraform.  It could be created by an idependent terraform module that is run before the openshift installer program though.

* The bootstrap instance and related resources (S3 bucket for boostrap ignition file), creation should be done in an independent module, so they can be easily deleted after installation.

* Add user defined tags to the install-config.yaml file

* Define the instance type for master and workers in variables

* Tag all resources created by terraform with kubernetes.io/cluster/....
