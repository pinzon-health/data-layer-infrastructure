#!/bin/bash

# Check if correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <environment> <action>"
    echo "Environment: staging or production"
    echo "Action: plan or apply"
    exit 1
fi

# Assign arguments to variables
environment=$1
action=$2

# Validate environment
if [[ "$environment" != "staging" && "$environment" != "production" ]]; then
    echo "Invalid environment. Use 'staging' or 'production'."
    exit 1
fi

# Validate action
if [[ "$action" != "plan" && "$action" != "apply" ]]; then
    echo "Invalid action. Use 'plan' or 'apply'."
    exit 1
fi

# Function to run Terraform commands
run_terraform() {
    echo "Switching to $environment workspace"
    terraform workspace select $environment || terraform workspace new $environment

    echo "Running terraform $action for $environment"
    terraform $action -var-file="vars/$environment.tfvars"
}

# Run Terraform
run_terraform

echo "Terraform $action for $environment completed."