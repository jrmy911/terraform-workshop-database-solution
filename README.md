# Terraform on Azure — database solution

Complete reference solution for the **two-hour, Terraform-first database assignment**. It manages exactly three Azure resources in the existing sandbox subscription:

1. `azurerm_resource_group.workshop`
2. `azurerm_mssql_server.workshop`
3. `azurerm_mssql_database.workshop`

A single `azurerm_client_config.current` data source reads the existing signed-in identity. No Entra users, role assignments, secrets or networking resources are created.

## Guides

- **[solution.html](solution.html)** — self-contained French/Dutch solution with the workshop's original design, navigation, copy buttons and local completion tracking.
- [Français](README.fr.md) · [Nederlands](README.nl.md) — step-by-step answers, including the initial resource group, variables, dependencies, outputs, tag change, preview-only `prd` plan and cleanup.
- The `.tf` files are the complete final configuration. The step-4 `training = "database"` tag is already present; the guides explain how to demonstrate its addition.

The HTML guide works offline without a web server. Azure operations and external documentation links need internet access.

## Before running

1. Use the existing sandbox subscription and an interactive user account via `az login`.
2. Set `ARM_SUBSCRIPTION_ID` in the same terminal; the bilingual guides contain Bash and PowerShell commands.
3. Replace `jdoe` in the three names in `main.tf` with your own abbreviation and `a1b2` with a globally unique lowercase alphanumeric suffix.
4. Check deployment and SQL/Entra configuration permissions, `Microsoft.Sql` registration, sandbox policy and regional availability of the `Basic` database tier before the workshop.
5. Keep this directory's state separate from the participant directory. Use different Azure resource names for an instructor demo. **Never manage the same resources from two independent state files.**

Read-only preflight examples:

```shell
az account show --output table
az provider show --namespace Microsoft.Sql --query registrationState --output tsv
az sql db list-editions --location westeurope --output table
```

These checks are not a substitute for an instructor rehearsal: Azure policy, identity permissions and live regional capacity must also allow the deployment.

## Run the complete solution

From this directory, after login, subscription selection and name customization:

```shell
terraform init
terraform fmt
terraform validate
terraform plan "-var-file=acc.tfvars"
terraform apply "-var-file=acc.tfvars"
terraform output
terraform state list
terraform plan "-var-file=acc.tfvars"
```

Read each plan before confirming. The last plan should report **No changes**. The first deployment should create three resources; the data source is a read, not a fourth creation.

To compare input values without deploying another configuration:

```shell
terraform plan "-var-file=prd.tfvars"
terraform plan "-var-file=acc.tfvars"
```

**Do not apply `prd.tfvars`.** It uses the same state and group, changes SQL names and proposes replacement; it is not an isolated production environment.

## Security, cost and cleanup

- Entra-only SQL authentication uses the existing signed-in identity. No SQL administrator password is needed or stored.
- Public SQL access is disabled. No private endpoint is created, so SQL connections are deliberately unavailable. Terraform provisions through Azure's management API.
- `Basic`, 2 GB and local backup storage are disposable workshop settings, not a production database design. No real data belongs here.
- Even an unused database incurs charges. Clean up after the session:

```shell
terraform destroy "-var-file=acc.tfvars"
terraform state list
```

Verify the resource group is gone and the state list is empty. Keep the state and ask for help if deletion fails; never delete the state to hide a failure. Do not share state files or saved plans.

The dependency lock file pins the AzureRM version used for local validation. Neither the assignment nor this solution has been deployed to Azure by the assistant; local checks cannot verify sandbox permissions, policy or capacity.
