#Public DNS domain creator

This terraform module will create a public DNS hosted zone based on a preexisting base domain.  This is usefull in case the base domain already contain other records and a new subdomain is prefered to keep DNS records for the cluster independent.

Two variables are required to run this module:

* **dns_domain_ID**.- This is the domain ID managed by AWS under which the subdomain will be created.

* **subdomain_name**.- The name of the subdomain to create.

Before running this module for the first time, Terraform needs to be initialized in the directory where the files are:

```shell
$ terraform init
```

An example execution looks like:

```shell
$ terraform apply -var="dns_domain_ID=Z1UP35G9G4AYY4YK6" -var="subdomain_name=clarisse"
```

Two output variables are produced:

* The full name of the new DNS domain, for the above example _clarisse.example.com._

* The zone ID of the new domain, that can be used with the Terraform module to create the resources for the OCP cluster.
