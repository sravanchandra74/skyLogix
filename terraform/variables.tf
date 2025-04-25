variable "region" {
  type    = string
  default = "eu-north-1"
}

variable "user" {
  type    = string
  default = "ec2-user"
}

variable "allowed_ssh_cidrs" {
  type = list(string)
  description = "List of CIDR blocks allowed to SSH to the bastion host."
  default     = ["85.253.33.237/32"] # IMPORTANT: Replace with your actual IP!
}