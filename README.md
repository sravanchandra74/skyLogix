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
        └── playbook.yml
        └── ansible.cfg
    ├── run.sh
    ├── README.md

## Change the path of directory where you cloned the repository (pwd)
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
![image](https://github.com/user-attachments/assets/89123d5e-22f5-4847-96f6-c87bb98cb32f)

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
        * 3 EC2 instances in 1 private subnet (no direct internet access)
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
    * Creates nginx-logs group in CloudWatch
    * Sends Docker logs to CloudWatch Logs for live streaming from private EC2s

## Run the run.sh File

* It is an interactive script which needs to choose the option for provisioning or deploying and destroying the AWS services.
* For Terraform infrastructure provisioning and Ansible script execution, choose option \[1].
* For destroying the infrastructure and deployment, choose option \[2].
* For exiting the process or come out of shell, choose option \[3].

##   Nature of ALB

ALB automatically scales its capacity to handle changes in traffic when Docker containers are stopped.

![ALB Scaling 1](https://github.com/user-attachments/assets/7e919947-edcb-48a4-b7ea-840dd75f8c42)
![ALB Scaling 2](https://github.com/user-attachments/assets/43344004-b189-4729-8202-450f98c8f496)
![ALB Scaling 3](https://github.com/user-attachments/assets/696e65dc-a770-4959-86f8-d3e66efbd65b)

##   CloudWatch Log Streams

![CloudWatch Logs 1](https://github.com/user-attachments/assets/b21ec37f-f018-493c-86d1-54e31cde33ba)
![CloudWatch Logs 2](https://github.com/user-attachments/assets/5e89c60f-dfd0-49aa-842a-5d5081c567ff)
![CloudWatch Logs 3](https://github.com/user-attachments/assets/07cee849-4de1-43e4-9090-3759874db325)

##   References

* [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources)
* [Ansible Docker Module](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_image_module.html)
* [AWS-AIOps Repo](https://github.com/sravanchandra74/AWS-AIOps)
* [Docker AWSLogs Logging Driver](https://docs.docker.com/engine/logging/drivers/awslogs/)


