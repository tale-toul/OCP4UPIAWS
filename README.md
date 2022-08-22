# Openshift UPI instalation on AWS

## Table of contents

* [Introduction](#introduction)
* [Requirements](#requirements)
* [Installation instructions](#installation-instructions)
  * [Ignition files creation](#ignition-files-creation)
  * [Terraform initialization](#terraform-initialization)
  * [Creating the infrastructure on AWS](#creating-the-infrastructure-on-aws)
  * [Openshift install completion](#openshift-install-completion)
* [Deleting bootstrap resources](#deleting-bootstrap-resources)
* [Deleting the cluster](#deleting-the-cluster)
* [User data for the EC2 instances](#user-data-for-the-ec2-instances)
* [CIDR definition](#cidr-definition)
* [References](#references)
* [Pending tasks](#pending-tasks)

## Introduction

This project contains the necesary instructions to deploy an Openshift 4 public cluster on AWS using the UPI installation method.

These instructions have been tested on Openshift versions from 4.5 to 4.10

Checkout the appropriate tag for the Openshift version that is to be deployed.
```
git tag
4.10
4.5
4.6
4.7
4.8
4.9
```
For example to deploy an Openshift 4.8 cluter:
```
git checkout 4.8
```

## Requirements

* An [AWS account](https://aws.amazon.com) with sufficient privileges to create the resources required by Openshift.  The account credentials are requested by the openshift installer, and terraform expects them in the default file **$HOME/.aws/credentials** or in the environment variables **AWS_ACCESS_KEY_ID**, **AWS_SECRET_ACCESS_KEY**, see [terraform documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#environment-variables)

* A public DNS domain, managed by AWS, to publish the cluster on.  The AWS account provided to the Openshift installer must be able to create records in that zone.  There is a convenient module to create a DNS subdomain in the directory  **ExternalDNSHostedZone**.  If the cluster is private this DNS domain is not required, but at the moment this project will not create a private cluster.

* A [Red Hat account](https://access.redhat.com).  At least a free Red Hat account is required to download the Openshift installer components.

* At least 500MB of disk space in the host where the installation is run from

* [Terraform](https://www.terraform.io/) must be installed in the local host.
  The terraform installation is straight forward, just follow the instructions for your operating system in the [terraform site](https://www.terraform.io/downloads.html)
  
## Installation instructions

These installation steps follow the instructions provided at [the official Red Hat documentation](https://docs.openshift.com/container-platform/4.10/installing/installing_aws/installing-aws-user-infra.html), but in this case Terraform is used to create the resources in AWS instead of CloudFormation.
1. Clone this github repository.  All other files and directories must be downloaded and created inside the repository's directory.
   ```
   git clone https://github.com/tale-toul/OCP4UPIAWS
   ```
1. [Download the installation program, pull secret and command line tools](https://cloud.redhat.com/openshift/install).- In section **Run it yourself**, select AWS as the cloud provider, then User-provided infrastructure.  Download the installer and command line tools for operating system required.  Download the pull secret as a file for later use.  

   The link above contains the latest version of the Openshift components, for earlier versions use [this link](https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/) and click on the desired version.  The pull secret must be obtained from the first link.

   Uncompress the intall program and cli tools.  Do this in the repository's local directory created when it was cloned:

   ```shell
   tar xvf openshift-install-linux.tar.gz
   sudo tar xvf openshift-client-linux.tar.gz  -C /usr/local/bin/
   ```

1. [Create an ssh key pair](https://docs.openshift.com/container-platform/4.4/installing/installing_aws/installing-aws-user-infra.html#ssh-agent-using_installing-aws-user-infra).- This key will be installed in the bootstrap host and every node in the cluster, and will allow passwordless connections to those machines.  

     This step is not extrictly required because ssh connections to the cluster nodes are not recommended, but it is still a convenient tool in case any issues come up during cluster installation.

     An already existinig ssh key pair can be used, as long as it is present in the direcotry ~/.ssh

```shell
 $ ssh-keygen -o -t rsa -f upi-ssh -N "" -b 4096
```

The previous command will produce two files: upi-ssh and upi-ssh.pub.  Copy them both to the directory **~/.ssh** so they can be used in the nex step:

```shell
$ cp upi-ssh* ~/.ssh
```

### Ignition files creation

1. [Create the **install-config.yaml** file](https://docs.openshift.com/container-platform/4.4/installing/installing_aws/installing-aws-user-infra.html#installation-generate-aws-user-infra-install-config_installing-aws-user-infra).- This is the configuration file that describes the cluster. The easiest way to create the file is by using the openshift install program with the options **"create install-config"** and answer the questions asked.  

   The option **--dir** is followed by a directory name, the terraform manifests expect the name of the directory and the name of the cluster to be the same, otherwise the creation of the AWS resources will fail.  It is best to use an empty directory or a non existing one to avoid conflicting with any previous installation, if the directory does not exist the installation program will create it:

   The command asks for:

   * The ssh keys to be installed in the EC2 instances. Selected from those already in ~/.ssh
   * The platform provider, AWS in this case
   * The credentials of the AWS account to use to deploy the resources.  If the file **~/.aws/credentials** exists and contains valid credentials, these will be used and this question is skipped.
   * The AWS region where the cluster will be deployed
   * The base DNS domain to use for the cluster public URLs.  This domain must already exist and be managed by AWS.
   * A name for the cluster, used as the base for naming the resources, and will be added to the above DNS domain
   * The pull secret to download container images from Red Hat.  Paste the contents of the pull-secret file downloaded before.
   
   ```
    $ ./openshift-install create install-config --dir clover
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
   The previous command will create the directory _clover_, if it does not already exist, and create the file **install-config.yaml** inside it.

1. Make any [changes](https://docs.openshift.com/container-platform/4.4/installing/installing_aws/installing-aws-customizations.html#installation-configuration-parameters_installing-aws-customizations) to the install-config.yaml required for the installation, in the example bellow, user defined tags have been added:

   ```yaml
   platform:
     aws:
       region: eu-west-3
       userTags:
         Environment: UAT
         Planet: Earth
   ```

1. Backup the **install-config.yaml** file outside of the clover directory; the file will be consumed and destroyed in the next step.

1. Create the Kubernetes manifests for the cluster

   ```shell
   ./openshift-install create manifests --dir clover
   INFO Credentials loaded from the "default" profile in file "/home/user/.aws/credentials" 
   INFO Consuming Install Config from target directory 
   INFO Manifests created in: daya/manifests and daya/openshift
   ```

1. Remove the Kubernetes manifest files that define the control plane machines. This prevents the installer from creating the control plane (master) nodes.  These machines will be created later by terraform.

   ```
   rm -fv clover/openshift/99_openshift-cluster-api_master-machines-*.yaml
   ```
1. Remove the Kubernetes manifest files that define the worker machines.  This prevents the installer to create the compute nodes.  These machines will be created later by terraform.
   ```
   rm -fv clover/openshift/99_openshift-cluster-api_worker-machineset-*
   ```
1. Create an empty file in the Terraform directory to store the variable assigments that will later be used by the terraform command to create the infraestructure.  The file does not need to have a specific name or extension, but if the extension is **.tfvars** it will be automatically loaded by terraform:

   ```shell
   touch Terraform/clover.vars
   ```
1. Get the value for the public zone id from the file **clover/manifests/cluster-dns-02-config.yml** and add an entry to the variable assigment file created before for the variable **dns_domain_ID**. Check that the base DNS domain (baseDomain) matches the one selected during install-config.yaml creation:

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
   
   The contents of the clover.vars should look like:
   ```
    $ cat Terraform/clover.vars
   dns_domain_ID="Z00659431CO1O47AE0285"
   ```
1. Create the ignition files.  This process will remove the manifest files:

   ```shell
   ./openshift-install create ignition-configs --dir clover
   INFO Consuming Openshift Manifests from target directory 
   INFO Consuming Worker Machines from target directory 
   INFO Consuming Common Manifests from target directory 
   INFO Consuming Master Machines from target directory 
   INFO Consuming OpenShift Install (Manifests) from target directory 
   INFO Ignition-Configs created in: clover and clover/auth
   ```

### Terraform initialization

Terraform is used to create the infrastructure components of the VPC, some of these components can be adjusted via the use of variables defined in the file _Terrafomr/input-vars.tf_, like the name of the cluster, the name of the DNS subdomain, etc.

Before running terraform for the first time it needs to be initialized, run the following command in the directory where the terraform manifest files are located:

```shell
cd Terraform
terraform init

Initializing modules...
- bootstrap in Boostrap

Initializing the backend...

Initializing provider plugins...
- Finding latest version of hashicorp/aws...
- Installing hashicorp/aws v4.27.0...
- Installed hashicorp/aws v4.27.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

### Creating the infrastructure on AWS

1. Get the infrastructure name assigned by the installer, this consists of the clustername followed by a short random string.  This name will be used later as the base of other infrastructure component names: 

   ```shell
    cat clover/metadata.json |jq -r .infraID
   clover-ltwcq
   ```
1. Add an entry to the variable assigment file created before for the variable **infra_name**:

   ```shell
    cat Terraform/clover.vars
   dns_domain_ID="Z00659431CO1O47AE0285"
   infra_name = "clover-v5fgv"
   ```
1. Get the encoded certificate authority to be used by the master instances.  This is the long string located in the master ignition file **clover/master.ign** and looks like this:

   `data:text/plain;charset=utf-8;base64,LS0tLS1CRUdJTiBDRVJUSUZJQ0<..long string of characters..>==`

   This long string must be assigned to the variable **master_ign_CA** in the variables assigment file created before:

   ```shell
    cat Terraform/clover.vars
   dns_domain_ID="Z00659431CO1O47AE0285"
   infra_name = "clover-v5fgv"
   master_ign_CA = "data:text/plain;charset=utf-8;base64,LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0t........LS0tCk1JSS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="
   ```
1. Review the rest of the variables in the file input-vars.tf, in particular the **region_name** must be the same that was used when creating the install-config.yaml file. Add any variable definition to the variables assigment file: 

   ```shell
    cat Terraform/clover.vars
   dns_domain_ID="Z00659431CO1O47AE0285"
   infra_name = "clover-v5fgv"
   master_ign_CA = "data:text/plain;charset=utf-8;base64,LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0t........LS0tCk1JSS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg=="
   region_name = "eu-west-3"
   ```
1. Make sure the asw account credentials are defined in the file $HOME/.aws/credentials or in the environment variables **AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY** as explained in [terraform documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#shared-configuration-and-credentials-files)
1. Go to the Terraform directory and run a command like the following:

   ```shell
     cd Terraform 
     terraform apply -var-file clover.vars
   ```
   Alternatively the variables can be assigned in the command line:
   
   ```shell
   $ terraform apply -var="region_name=eu-west-3" -var="infra_name=clover-ltwcq" -var="dns_domain_ID=Z00659431CO1O47AE0285" \
     -var="master_ign_CA=data:text/plain;charset=utf-8;base64,LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1J....."
   ```
   
   Terraform analizes the information provided and asks for confirmation before proceding with the actual creation of resources:
   ```
   ...
   Plan: 131 to add, 0 to change, 0 to destroy.
   ...
   Do you want to perform these actions?
     Terraform will perform the actions described above.
     Only 'yes' will be accepted to approve.
   
     Enter a value:
   ```
   It will take a few minutes for Terraform to create all resources.  The resources will come up in the AWS web console as they are being created.

   When all resources are created, in particular the bootstrap and control plane machines, the Openshift installation process starts automatically without the need from the user to do any additional step.

### Openshift install completion

On another terminal run the following command to see how the installation is progressing, and wait for the message saying it is safe to remove the bootstrap resources.
```shell
$ ./openshift-install wait-for bootstrap-complete --dir clover/ --log-level info
INFO Waiting up to 20m0s for the Kubernetes API at https://api.clover.tale.rhcee.support:6443... 
INFO API v1.17.1+166b070 up                       
INFO Waiting up to 40m0s for bootstrapping to complete... 
INFO It is now safe to remove the bootstrap resources
```
The log file for the installation may be useful in case of failure, it is located at **clover/.openshift_install.log**

Another way to peek into the installation process is to ssh into the bootstrap instance and run the journalct command:

```shell
$ ssh core@<IP of bootstrap instance>
bootstrap $ journalctl -b -f
```

When the bootstrap process has completed successfully with the message: `INFO It is now safe to remove the bootstrap resources`.  The master nodes still need a few minutes to be ready.

Despite the message keep the bootstrap resources around until the end of the intallation, they are useful for troubleshooting in case anything goes wrong.  Check the section [Deleting bootstrap resources](#deleting-bootstrap-resources) for instructions on how to remove those resources.

Login to the cluster using the CLI by exporting the variable KUBECONFIG using the path to the file **kubeconfig** created by the openshift-install program.  Using a relative path like in the following example will require to run the oc commands ffrom the same directory where the relative path is valid:

```shell
export KUBECONFIG=clover/auth/kubeconfig
```

Run a test command to check is the cluster is ready:

```shell
$ oc whoami
system:admin
```
If you get an error, wait a few minutes and try again

On a new window run the following command to check on the completion of the installation.  This command is not strictly required, is just shows information about the installation process:

```shell
./openshift-install --dir clover/ wait-for install-complete --log-level info
INFO Waiting up to 40m0s (until 11:00AM) for the cluster at https://api.clover.jjerezro.emeatam.support:6443 to initialize...
```

Get the list of nodes, at this stage only master nodes should be available:

```
$ oc get nodes
NAME                                         STATUS   ROLES    AGE   VERSION
ip-10-0-139-182.eu-west-3.compute.internal   Ready    master   41m   v1.17.1+1aa1c48
ip-10-0-156-148.eu-west-3.compute.internal   Ready    master   41m   v1.17.1+1aa1c48
ip-10-0-165-4.eu-west-3.compute.internal     Ready    master   41m   v1.17.1+1aa1c48
```
The worker nodes need to be admited in the cluster, two certificate signing requests (csr) per worker node must be approved manually by the administrator.
Get the list of csr's with the command:

```shell
$ oc get csr|grep Pending
csr-dptjn   5m39s   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper   Pending
csr-h6r66   5m40s   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper   Pending
csr-xlmr2   5m38s   system:serviceaccount:openshift-machine-config-operator:node-bootstrapper   Pending
```
The list can be longer because the csr's have a short life span, new ones get added every 15 minutes if the old ones have not been approved.
Approve the 3 most recent csr's

```shell
$ oc adm certificate approve csr-dptjn csr-h6r66 csr-xlmr2
certificatesigningrequest.certificates.k8s.io/csr-dptjn approved
certificatesigningrequest.certificates.k8s.io/csr-h6r66 approved
certificatesigningrequest.certificates.k8s.io/csr-xlmr2 approved
```

The approval of the above crs's will trigget the generation of 3 additional ones with a shorter name:

```shell
$ oc get csr|grep Pending
csr-67f6q   53s   system:node:ip-10-0-166-103.eu-west-3.compute.internal                      Pending
csr-flh5d   52s   system:node:ip-10-0-147-76.eu-west-3.compute.internal                       Pending
csr-mlfn5   58s   system:node:ip-10-0-136-46.eu-west-3.compute.internal                       Pending
```
Again approve the 3 most recent ones:

```shell
$ oc adm certificate approve csr-67f6q csr-flh5d csr-mlfn5
certificatesigningrequest.certificates.k8s.io/csr-67f6q approved
certificatesigningrequest.certificates.k8s.io/csr-flh5d approved
certificatesigningrequest.certificates.k8s.io/csr-mlfn5 approved
```
Now the worker nodes should appear in the list of cluster nodes, although they may take a couple minutes reach the Ready status:

```shell
$ watch oc get nodes
NAME                                         STATUS   ROLES    AGE     VERSION
ip-10-0-136-46.eu-west-3.compute.internal    Ready    worker   5m21s   v1.17.1+1aa1c48
ip-10-0-139-182.eu-west-3.compute.internal   Ready    master   58m     v1.17.1+1aa1c48
ip-10-0-147-76.eu-west-3.compute.internal    Ready    worker   5m16s   v1.17.1+1aa1c48
ip-10-0-156-148.eu-west-3.compute.internal   Ready    master   59m     v1.17.1+1aa1c48
ip-10-0-165-4.eu-west-3.compute.internal     Ready    master   58m     v1.17.1+1aa1c48
ip-10-0-166-103.eu-west-3.compute.internal   Ready    worker   5m17s   v1.17.1+1aa1c48
```
The inclusion of the worker nodes will trigger the deployment of many of the services that run on worker nodes, check the status of the cluster operators until all of them are available, not progressing and not degraded:

```shell
$ watch oc get co
NAME                                       VERSION   AVAILABLE   PROGRESSING   DEGRADED   SINCE
authentication                             4.4.11    True        False         False      2m40s
cloud-credential                           4.4.11    True        False         False      68m
cluster-autoscaler                         4.4.11    True        False         False      55m
console                                    4.4.11    True        False         False      5m42s
csi-snapshot-controller                    4.4.11    True        False         False      9m4s
dns                                        4.4.11    True        False         False      61m
etcd                                       4.4.11    True        False         False      61m
image-registry                             4.4.11    True        False         False      9m42s
ingress                                    4.4.11    True        False         False      9m5s
insights                                   4.4.11    True        False         False      55m
kube-apiserver                             4.4.11    True        False         False      61m
kube-controller-manager                    4.4.11    True        False         False      60m
kube-scheduler                             4.4.11    True        False         False      59m
kube-storage-version-migrator              4.4.11    True        False         False      9m19s
machine-api                                4.4.11    True        False         False      55m
machine-config                             4.4.11    True        False         False      62m
marketplace                                4.4.11    True        False         False      55m
monitoring                                 4.4.11    True        False         False      7m22s
network                                    4.4.11    True        False         False      63m
node-tuning                                4.4.11    True        False         False      63m
openshift-apiserver                        4.4.11    True        False         False      55m
openshift-controller-manager               4.4.11    True        False         False      55m
openshift-samples                          4.4.11    True        False         False      54m
operator-lifecycle-manager                 4.4.11    True        False         False      62m
operator-lifecycle-manager-catalog         4.4.11    True        False         False      62m
operator-lifecycle-manager-packageserver   4.4.11    True        False         False      56m
service-ca                                 4.4.11    True        False         False      63m
service-catalog-apiserver                  4.4.11    True        False         False      63m
service-catalog-controller-manager         4.4.11    True        False         False      63m
storage                                    4.4.11    True        False         False      55m
```

When all cluster operator are ready, the openshift-install command that had been run previously in another window should also finish successfully:

```shell
$ ./openshift-install wait-for install-complete --dir clover/ --log-level info
INFO Waiting up to 30m0s for the cluster at https://api.clover.tale.rhcee.support:6443 to initialize... 
INFO Waiting up to 10m0s for the openshift-console route to be created... 
INFO Install complete!                            
INFO To access the cluster as the system:admin user when using 'oc', run 'export KUBECONFIG=/home/clover/auth/kubeconfig' 
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.clover.example.com
INFO Login to the console with user: kubeadmin, password: amDqg-bjVCH-TLBfQ-zdJnu
```
The cluster is now installed and ready to be used.

The bootstrap resources can be deleted.

## Deleting bootstrap resources

The boostrap EC2 instance and related resources are created by Terraform as an independent module.  This allows for the deletion of these resources without afecting the rest of the Openshift cluster.

The command requires the use of the option `-target module.bootstrap` to inform terraform that only bootstrap reources must be deleted.  

**WARNING** If the target option is not used, terraform will delete all resources, resulting in the destruction of the cluster.

The following is an example command:
```shell
$ terraform destroy -var-file clover.vars -target module.bootstrap
```
This command will show the following warning message that can be safely ignored:

```
Warning: Resource targeting is in effect
```
After terraform destroys the bootstrap module resources another warning message is shown, again this message can be ignored:
```
Warning: Applied changes may be incomplete
```

## Deleting the cluster

Part of the cluster resources were created by terraform, and part were created by the Openshift installer afterwards.  To make sure all resources are deleted, both the openshift installer and terraform are used.  

Two terminals are requied to follow this procedure:

In one terminal run the following openshift-intall command, this will trigger the removal of part of the resources:

```shell
./openshift-install destroy cluster --dir clover --log-level info
```
Leave the above command running for a few minutes, if at some point it gets stuck and doesn't go any further, run the terraform destroy command in another terminal.
```shell
terraform destroy -var-file clover.vars
```
The above command will unlock the first command on the other terminal.  Finally all resources will get deleted.


## User data for the EC2 instances

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
## CIDR definition 

When the **install-config.yaml** file is created by the openshift-install program there is a default CIDR definition that represents the network address space that will be used for the machines created in the cluster:

```yaml
...
networking:
  machineNetwork:
  - cidr: 10.0.0.0/16
```

This CIDR definition must match the **cidr_block** argument used to create the VPC in terraform, and the corresponding **cidr_block** definitions of each of the subnets created inside that VPC.  

To simplify the configuration the variable **vpc_cidr** is used in terraform to hold the value of the CIDR, its default value matches the default value assigned by openshift-install when creating the install-config.yaml file:

```yaml
variable "vpc_cidr" {
  description = "Network segment for the VPC"
  type = string
  default = "10.0.0.0/16"
}
```

The subnets definition also uses the same variable **vpc_cidr** to compute the value for the CIDR assigned to it.  

The subnets are created using a loop based on the variable **count** so that variable is used to assign the value of the third byte in the network definition `${count.index * 16}`.
The first two bytes of the network definition is base on the **vpc_cidr**, a regular expression is used to extract the first two numbers followed by dots from the variable:  

```yaml
resource "aws_subnet" "subnet_pub" {
    count = local.public_subnet_count
    ...
    #CIDR: <cidr fix part>.0.0/20; <cidr fix part>.16.0/20; <cidr fix part>.32.0/20; 
    cidr_block = "${regex("^\\d+\\.\\d+\\.",var.vpc_cidr)}${count.index * 16}.0/20"
...
```
For example for the default CIDR of 10.0.0.0/16, the first 3 subnets would be: 10.0.0.0/20; 10.0.16.0/20; 10.0.32.0/20.  The 10.0. part is extracted by the regular expression, the thir byte, 0, 16, 32 is computed by the expression `${count.index * 16}` and the finel 0/20 is constant.

## References

[0] [Installation and update](https://docs.openshift.com/container-platform/4.4/architecture/architecture-installation.html#architecture-installation)
[1] [Installing a cluster on user-provisioned infrastructure in AWS by using CloudFormation templates:](https://docs.openshift.com/container-platform/4.4/installing/installing_aws/installing-aws-user-infra.html)

## Pending tasks

* Allow the creation of a private (Internal) cluster

* After installation worker nodes should be replaced with another set backed by machinesets
