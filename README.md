## Pre-requisites

* Terraform installed on local/remote machine
* Git installed on local/remote machine
* Visual Studio Code, IntelliJ, or any preferred IDE
* AWS account
* AWS account integrated with VS Code using access\_key and secret\_access\_key via TF\_VARS
* Clone the Git repository: skyLogix

## Directory Structure

    skyLogix/
    ├── terraform/
    │   ├── main.tf
    │   ├── ec2.tf
    │   ├── network.tf
    │   ├── alb.tf
    │   ├── variable.tf
    │   ├── output.tf
    │   ├── iam.tf
    │   └── provider.tf
    └── ansible/
        └── docker-nginx/
            ├── tasks/
            │   └── main.yml
            ├── vars/
            │   └── main.yml
            ├── meta/
            │   └── main.yml
            ├── handlers/
            │   └── main.yml
            └── templates/
                ├── nginx.conf.j2
                └── index.html.j2
    ├── run.sh

## Change the directory path where you cloned the repository (pwd)
## run.sh File Paths

    TERRAFORM_DIR="~/skyLogix/terraform"
    KEY_FILE_PEM="~/skyLogix/bastion_access_key.pem"

## terraform/ec2.tf File Paths

* For bastion aws\_instance resource:

        source = "~/skyLogix/bastion_access_key.pem"

* At resource local\_file "hosts\_file":

        filename = "~/skyLogix/hosts"

* At resource null\_resource "copy\_ansible\_config":

        source = "~/skyLogix/ansible/ansible.cfg"
        source = "~/skyLogix/hosts"
        source = "~/skyLogix/ansible"

## terraform/network.tf File Paths

    resource "local_file" "bastion_private_key" {
      filename = "~/skyLogix/bastion_access_key.pem"
    }

## terraform/variable.tf File

    variable "allowed_ssh_cidrs" {
      type    = list(string)
      default = ["<your-ip>/32"] # IMPORTANT: Replace with your actual IP!
    }

## Architectural Design

The following architectural design is implemented to achieve the objectives:

### Core Components

* Terraform Provisioning
    * AWS Region: eu-north-1
    * VPC CIDR: 10.161.0.0/24 (256 IPs)
    * Availability Zones: eu-north-1a, eu-north-1b
    * Subnets:
        * 2 public subnets (one in each AZ)
        * 1 private subnet (in one AZ)
    * Gateways:
        * Internet Gateway (for inbound/outbound internet traffic)
        * NAT Gateway (to provide internet access to private subnet)
    * EC2 Instances:
        * Bastion Host in 1 public subnet
        * 3 EC2 instances in private subnet (no direct internet access)
    * ALB: Application Load Balancer deployed in public subnets
    * Elastic IP: Associated with the NAT Gateway
    * Route Tables: For both public and private subnets
    * Security Groups:
        * SG for Bastion (SSH access)
        * SG for private EC2 (access from Bastion only)
        * SG for ALB
    * Key Pairs: PEM file used to SSH into Bastion and from Bastion to private EC2s
    * AMI: Amazon Linux for all EC2 instances
    * IAM Roles/Policies: For enabling CloudWatch log access
* Ansible Playbook
    * Installs Docker on all private EC2 instances
    * Pulls, tags, and runs the Nginx container
    * Creates nginx-logs group
    * Sends Docker logs to CloudWatch Logs for live streaming from private EC2s

* Cloudwatch Log Streams
    
