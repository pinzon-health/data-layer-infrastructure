# Data Layer
 
This Terraform configuration deploys an Aurora PostgreSQL 14.6 Serverless v2 cluster along with the necessary infrastructure components like VPC, security group, and subnets.

## Prerequisites

- Install [Terraform](https://www.terraform.io/downloads.html) (version 0.14 or later)

## Project Structure

Create the following files and directories:

- `main.tf`: Contains the provided Terraform code
- `variables.tf`: Defines the `environment` variable
- `vars/dev.tfvars.example`: vars example file, to be renamed to `dev.tfvars`, `stage.tfvars`, etc...
- `outputs.tf`: (Optional) Outputs important information after Terraform runs
- `keys/ENV/keyfile.pem` - pem file (SSH)
- `README.md`: This file with instructions

## Getting Started

1. **Initialize Terraform:**

   Open a terminal/command prompt, navigate to the project directory, and run:
   ```bash
   $ terraform init
   ```
2. **Add a Workspaces:**
   ```bash
   $ terraform workspace new staging   
   $ terraform workspace select staging   
   ```
3. **Apply the Terraform configuration:**

    Run the following command to create the resources:
   ```hcl
   $ terraform apply
   # if there is a env vars file (different ways to handle env vars - in a separate section)
   $ terraform apply -var-file="vars/dev.tfvars"
   ```
   Review the proposed changes and type `yes` when prompted to proceed.
4. **Check the outputs:**

    If you've created an `outputs.tf` file, you should see the output values after the `terraform apply` command finishes. You can also run `terraform output` at any time to view the output values.
    ```hcl
    $ terraform output > outputs-production.txt     
    ```

5. **Destroy the resources (optional):**

    If you want to delete the resources created by Terraform, run:

   ```hcl
   $ terraform destroy
   ```
   Review the proposed changes and type `yes` when prompted to proceed.

   Remember to replace the example parameters with your own values as needed.

## Environment Variables

There are several ways to pass different values for variables when running Terraform. Here are three common methods:

1. **Command-line arguments:**

   You can pass variable values directly via the command line using the `-var` option when running `terraform apply`. For example:

   ```hcl
   terraform apply -var="environment=stage"
    ```
   This will set the `environment` variable to "stage" for this run.

2. **Environment variables:**

   You can set environment variables with the `TF_VAR_` prefix to pass values to Terraform variables. For example:

   ```hcl
   export TF_VAR_environment=stage
   terraform apply
   ```
   
   This will set the `environment` variable to "stage" as well. Note that the environment variable names are case-insensitive, and they should be in lowercase for the variable name part after the `TF_VAR_` prefix.

   On Windows, use the `set` command to set environment variables:
    ```hcl
    set TF_VAR_environment=stage
    terraform apply
    ```

3. **Terraform variable files (recommended):**

   You can create a Terraform variable file (e.g., `stage.tfvars`) with variable values for a specific environment:

   ```hcl
   environment = "stage"
   ```

   Then, run the terraform apply command with the -var-file option:

   ```hcl
   terraform apply -var-file="stage.tfvars"
   ```

   This will set the environment variable based on the values in the stage.tfvars file. You can create multiple variable files for different environments and pass the appropriate file when running Terraform.

Choose any of the above methods that best suit your workflow and project requirements.

## terraform_run.sh
The terraform_run.sh script is designed to manage Terraform deployments for different environments (staging and production). It simplifies the process of planning and applying Terraform configurations by providing a streamlined command-line interface.

### Usage
To use the script, you need to provide two arguments: the environment and the action. The script will validate the inputs and execute the corresponding Terraform commands.
```hcl
./terraform_run.sh <environment> <action>
```

Arguments
* `<environment>`: The target environment for the Terraform commands. Acceptable values are staging or production.
* `<action>`: The action to be performed by Terraform. Acceptable values are plan or apply.

#### Example
```hcl
./terraform_run.sh staging plan
```

### Preconditions
Ensure that you have the following preconditions met before running the script:

* Terraform is installed and accessible in your environment.
* The necessary Terraform configuration files are present in the working directory.
* A vars directory exists with corresponding variable files (staging.tfvars and production.tfvars) for each environment.