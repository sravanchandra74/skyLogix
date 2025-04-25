#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display the menu
show_menu() {
  echo "Select an option:"
  echo "1) Terraform Apply (Provision Infrastructure)"
  echo "2) Terraform Destroy (Clean Up Infrastructure)"
  echo "3) Exit"
  read -p "Enter your choice [1-3]: " choice
}

# Directories
TERRAFORM_DIR="/Users/shravanchandraparikipandla/Documents/repo/yolo-test/terraform"
KEY_FILE_PEM="/Users/shravanchandraparikipandla/Documents/repo/yolo-test/bastion_access_key.pem"
ANSIBLE_DIR="/etc/ansible"
ANSIBLE_ROLES_DIR="/etc/ansible/roles"
ANSIBLE_HOSTS_FILE="/etc/ansible/hosts"

# Menu loop
while true; do
  show_menu
  case $choice in
    1)
      echo "You chose: Terraform Apply"
      echo "Running Terraform to provision infrastructure..."

      # Navigate to Terraform directory
      cd "$TERRAFORM_DIR"

      # Initialize Terraform
      terraform init

      # Plan and Apply Terraform
      terraform plan -out=tfplan
      terraform apply -auto-approve tfplan

      # Step 2: Run Ansible after Terraform Apply
      echo "Running Ansible playbook to configure the application on the build server..."

      # Extract the bastion server's IP from Terraform output
      BASTION_SERVER_IP=$(terraform output -raw bastion_public_ip)

      # SSH into the build server and run Ansible
      ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $KEY_FILE_PEM ec2-user@"$BASTION_SERVER_IP" << EOF
        set -e
        echo "Checking for required files on the build server..."

        # Check for the existence of the hosts file
        if [ ! -f "$ANSIBLE_HOSTS_FILE" ]; then
          echo "Error: Hosts file not found on the build server."
          exit 1
        fi

        # Check for the existence of the Ansible roles directory
        if [ ! -d "$ANSIBLE_DIR" ]; then
          echo "Error: Ansible roles directory not found on the build server."
          exit 1
        fi

        # Navigate to the Ansible roles directory
        echo "Navigating to Ansible roles directory..."
        cd $ANSIBLE_ROLES_DIR

        # Run the Ansible playbook
        echo "Running Ansible playbook..."
        ansible-playbook playbook.yml
EOF

      echo "Terraform Apply and Ansible execution completed successfully!"
      break
      ;;
    2)
      echo "You chose: Terraform Destroy"
      echo "Destroying infrastructure with Terraform..."

      # Navigate to Terraform directory
      cd "$TERRAFORM_DIR"

      # Initialize Terraform (in case it hasn't been initialized)
      terraform init

      # Destroy the infrastructure
      terraform destroy -auto-approve

      echo "Terraform Destroy completed successfully!"
      break
      ;;
    3)
      echo "Exiting the script."
      exit 0
      ;;
    *)
      echo "Invalid choice, please try again."
      ;;
  esac
done
