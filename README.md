# Hornsense-infra

This repo includes the infrastructure-as-code (IaC) for setting up the
serverless infrastructure for the Hornsense project. The code is expressed using
a custom language by Hashicorp, named Terraform. The homonymous software detects
changes in the code and applies the changes to the infrastructure, updating
configurations or recreating resources.

Given the infrastructure is in Amazon Web Services (AWS), the first required
set-up is to [configure your terminal access to AWS](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html). 

It is also a requirement to [install Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli). 
A software version manager will be useful for running older versions of the software.

## :warning: Currently deployed environments :warning:

| Project       | Stage         | Region    |
| ------------- | ------------- | --------- |
| hs            | dev           | us-west-2 |
| hose          | prod          | us-west-2 |

## AWS provider version and Terraform version
This repository's AWS provider version is currently set to the version last used
in April 2023, when changes were made to deployed resources. Versions 4.0.0 through
4.8.0 of the Hashicorp AWS provider introduced significant breaking changes. The
Terraform version is also constrained to the version available in April 2023 as 
well. **Commit .terraform.lock.hcl after applying changes to existing resources.** 

## :warning: The following steps with :warning: are used to create resources at AWS :warning:
## :warning: You are probably looking to use or change the existing resources :warning:

## Bootstrapping :warning:

The infrastructure state for the project is stored in an encrypted AWS S3 bucket.
Terraform automatically uploads and retrieves the state from the bucket, which is
seamless for infrastructure updates from anywhere. To create the initial
infrastructure to store the state, the IaC must be configured and initialized.

These three variables must be set and be the same in further usages in the IaC.

```
cd bootstrap
terraform init
terraform apply -var region=<region> -var project=<project> -var stage=<stage>
```

## Main Infrastructure :warning:

In the root of the repository is the code for the main infrastructure. To
initialize the infrastructure, we must define the parameters that will be used
for storing the infrastructure state (from the last step).

The file `backend.tfvars` must be created containing the parameters for the
state bucket and its encryption.
The required parameters are contained in the `backend.tfvars.example`.
In general, the region, project, and stage should be changed to match the ones
from bootstrapping. [Additional backend](https://www.terraform.io/docs/language/settings/backends/s3.html)
parameters can be included. After the file is created, the IaC can be
initialized:

```bash
terraform init -backend-config=backend.tfvars
```

Now, to create the resources from the IaC, we need to set up the variables used
in the main code. There is an example of variables in `terraform.tfvars.example`. 
The most important ones are the project, stage, region, availability zones
(`azn`), and domain name (`domain_name`). In general, the other variables are
not required to be changed. There are cases in which you may need a specific
networking configuration, and for that the other variables will be useful.

It is expected that there is a issued certificate for the informed domain in the
AWS Certificate Manager at region `us-east-1` (this is a current limitation for
API Gateway).

After the proper parameters are set up, you can create the infrastructure:

```bash
terraform apply
```

The command will create all the resources required to run the backend, including
Route53 records, the [handler lambda code](#lambda), and the [bastion instance](#bastion).

## Loading new envvars and deploying new versions of the Django project

The environment variables for the Django project are safely stored in a
[AWS SSM parameter store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html).
In order to set the variable values from a .env file, an utilitary was created:

```bash
./tools/load_env.py <project> <stage> .env
```

Afterwards, the project needs to be deployed to S3:

```bash
./tools/deploy.sh <project> <stage>
```

After deployment, the bastion instance needs to be used to migrations and static
content publication.

A cronjob keeps the Lambda function warm, so requests are answered as fast as
possible.
One caveat of this is that the project is not downloaded from the S3 bucket at
each request, requiring us to force-reload the lambda when making a new
deployment.
To do so, the following command does the trick:


```bash
./tools/refresh.sh <project> <stage>
```

## Lambda

All the API endpoints redirect to a Lambda function, which spins up Django and
inject the request information into it, to retrieve its response.
The initial code that Lambda executes is called `handler`, a small piece of code
that downloads the whole project from S3.
Some changes were performed to the original code from Django, to inject the
environment variables from the encrypted parameter store and point to the
correct S3 object.

## Bastion

Some database operations require direct access to the database, including
querying and Django records maintenance. However, this IaC sets up the database
into an enclosed network, closing it to external access. A bastion instance is
set up to perform migrations, static publishing, and using Django shell.

To access the bastion, you must use the AWS system manager to start a SSH
session.

Along with AWS CLI, you need to install a Session manager plugin.
https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html

The private key must be downloaded from Stache, at the URL:
https://stache.utexas.edu/entry/1bb6c68601c84027185402d8c3182bf1

The content of the secret must be stored in the file `~/.ssh/hs_bastion.pem`
and the file's permission must be adjusted to user readable only:
```
chmod 600 ~/.ssh/hs_bastion.pem
```

The command to start the session is the following:

```bash
./tools/start-session.sh <project> <stage> -i ~/.ssh/hs_bastion.pem
```

---

## How to Contribute

Before starting developing, install the [pre-commit](https://pre-commit.com/)
hooks to enable automatic syntax and security reviews:

```bash
pre-commit install
```
# Terraform_horn-rech
