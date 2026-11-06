# Terraform-workshop op Azure

**Doel:** kennismaken met resources, verwijzingen, variabelen, `.tfvars`-bestanden, outputs en de cyclus `plan → apply → destroy`.

**Oplossing voor de begeleider · 2 uur.** De `.tf`-bestanden in deze map vormen de volledige oplossing: drie resources en één data source, zonder netwerk of SQL-wachtwoord. De stappen hieronder volgen de deelnemersoefening. `solution.html` bevat dezelfde oplossing in het Frans en Nederlands en werkt offline.

## Voorbereiding

**Doel:** bereid een geïsoleerde demonstratie in dezelfde sandbox voor.

Terraform, Azure CLI en een editor moeten geïnstalleerd zijn. Controleer met `terraform version` en `az version`. Werk in deze map, los van de oorspronkelijke workshop: gebruik de state daarvan niet opnieuw.

Azure CLI (`az`) werkt in beide terminals. Meld je aan en selecteer de sandbox met het blok voor jouw terminal.

**Azure CLI in Bash (Linux/macOS/WSL):**

```bash
az login
az account set --subscription "<sandbox-subscriptie-id>"
az account show --output table
export ARM_SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
```

**Azure CLI in PowerShell (Windows):**

```powershell
az login
az account set --subscription "<sandbox-subscriptie-id>"
az account show --output table
$env:ARM_SUBSCRIPTION_ID = (az account show --query id --output tsv)
```

Gebruik je Microsoft Entra-gebruikersaccount met `az login`, geen service principal. De begeleider controleert vooraf de deploymentrechten, het instellen van de Entra-beheerder en de beschikbaarheid van Azure SQL in deze sandbox. Een andere subscription is niet nodig.

Vervang `jdoe` door je eigen afkorting in de Azure-namen: **`rg-terraform-db-workshop-jdoe`** voor John Doe. Vervang voor de SQL-server ook `a1b2` door een persoonlijke, unieke suffix van kleine letters en cijfers. Houd dezelfde waarden gedurende de hele workshop aan.


**Let op:** deploy de oplossing en oefening niet met dezelfde Azure-namen vanuit twee verschillende states. Gebruik voor de demonstratie een andere afkorting en suffix, of raadpleeg de oplossing zonder deze te deployen. Kopieer nooit state tussen de mappen.

De meegeleverde code bevat al de variabelen, drie resources, outputs en de uiteindelijke tag `training`. Begin voor een stapsgewijze demonstratie met een lege map en voeg de blokken in onderstaande volgorde toe. Om direct de volledige oplossing uit te voeren, na aanpassing van de namen:

```shell
terraform init
terraform fmt
terraform validate
terraform plan "-var-file=acc.tfvars"
terraform apply "-var-file=acc.tfvars"
```

Voer `apply` niet uit zonder het plan te lezen. SQL-toegang is bewust niet mogelijk: publieke toegang staat uit en er is geen private endpoint. De begeleider controleert vooraf SQL-/Entra-rechten, registratie van `Microsoft.Sql`, sandboxbeleid en beschikbaarheid van `Basic` in `westeurope`. Laat deelnemers deze vereisten niet tijdens de twee uur oplossen.

## 1. Eerste resource

**Doel:** krijg een eerste plan met één toevoeging en maak daarna de groep.

### `versions.tf`

```hcl
terraform {
  required_version = ">= 1.6, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81.0"
    }
  }
}
```

### `providers.tf`

```hcl
provider "azurerm" {
  features {}
}
```

### `main.tf` uitsluitend voor deze stap

```hcl
resource "azurerm_resource_group" "workshop" {
  name     = "rg-terraform-db-workshop-jdoe"
  location = "westeurope"

  tags = {
    environment = "acc"
    workshop    = "terraform"
  }
}
```

Commando’s: `terraform init`, `terraform fmt`, `terraform validate`, `terraform plan`, `terraform apply`. Gebruik de `.tfvars` nog niet: de variabelen zijn nog niet gedeclareerd. Een tweede plan na het aanmaken geeft **No changes** aan.

**Leg uit:** `azurerm_resource_group` is het type; `workshop` is het label in de code; `name` is de Azure-naam. Terraform maakt niet één resource per bestand: het leest alle `.tf`-bestanden in de map samen.

## 2. Variabelen en `.tfvars`-bestanden

**Doel:** scheid de configuratie van de invoerwaarden.

### `variables.tf`

```hcl
variable "environment" {
  description = "The environment label used in SQL resource names and the resource group tag."
  type        = string
}

variable "location" {
  description = "The Azure region for the workshop resources."
  type        = string
  default     = "westeurope"
}

variable "database_sku" {
  description = "The database service tier: Basic for the sandbox, S0 for a preview-only plan."
  type        = string
  default     = "Basic"
}
```

Vervang het groepsblok in `main.tf` nu door:

```hcl
resource "azurerm_resource_group" "workshop" {
  name     = "rg-terraform-db-workshop-jdoe"
  location = var.location

  tags = {
    environment = var.environment
    workshop    = "terraform"
  }
}
```

### `acc.tfvars` — om te deployen

```hcl
environment  = "acc"
location     = "westeurope"
database_sku = "Basic"
```

### `prd.tfvars` — alleen een plan

```hcl
# Preview only during this workshop; this is not a production-ready deployment.
environment  = "prd"
location     = "westeurope"
database_sku = "S0"
```

```shell
terraform fmt
terraform validate
terraform plan "-var-file=acc.tfvars"
terraform apply "-var-file=acc.tfvars"
```

De waarden zijn gelijk aan de eerste deployment: het plan hoort **No changes** aan te geven. `database_sku` is al gedeclareerd, maar wordt pas in stap 3.1 gebruikt. `environment` heeft geen standaardwaarde: je moet een waarde meegeven. De andere variabelen hebben een standaardwaarde, die het `.tfvars`-bestand kan overschrijven.

## 3. SQL-server en verwijzingen

**Doel:** maak een impliciete afhankelijkheid via verwijzingen, niet via gekopieerde IDs.

Voeg het volgende aan `main.tf` toe. Deelnemers krijgen de Entra-configuratie aangereikt; ze hoeven die tijdens de oefening niet zelf uit te zoeken:

```hcl
data "azurerm_client_config" "current" {}

resource "azurerm_mssql_server" "workshop" {
  name                          = "sql-tfdb-jdoe-${var.environment}-a1b2"
  resource_group_name           = azurerm_resource_group.workshop.name
  location                      = azurerm_resource_group.workshop.location
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  # Supplied configuration, not an authentication exercise.
  # The object ID identifies the administrator; the username is a display label.
  # Entra-only authentication avoids SQL passwords in the code and state.
  azuread_administrator {
    login_username              = "Workshop participant"
    object_id                   = data.azurerm_client_config.current.object_id
    tenant_id                   = data.azurerm_client_config.current.tenant_id
    azuread_authentication_only = true
  }
}
```

Pas de servernaam aan zoals in de voorbereiding beschreven. De data source leest de aangemelde identiteit; het Entra-blok maakt deze SQL-beheerder. `login_username` is een label en `object_id` identificeert het account. Er wordt geen extra gebruiker, rol of wachtwoord gemaakt.

Voer `fmt`, `validate`, `plan` en `apply` met `acc.tfvars` uit. Als alleen de groep al bestond, voegt het plan één server toe; het lezen van de data source is geen resourcetoevoeging.

**Verwacht antwoord:** `azurerm_resource_group.workshop.name` en `.location` koppelen de server aan de groep. Terraform begrijpt dat de groep eerst moet bestaan; `depends_on` is hier niet nodig. De logische server is geen VM. Publieke toegang uitschakelen blokkeert het beheer via de Azure-API niet, maar wel SQL-verbindingen vanaf de werkplek.

**Documentatie:** [SQL-server](https://registry.terraform.io/providers/hashicorp/azurerm/4.81.0/docs/resources/mssql_server) · [client-configuratie](https://registry.terraform.io/providers/hashicorp/azurerm/4.81.0/docs/data-sources/client_config).

## 3.1 Database

**Doel:** verwijs naar de server-ID en gebruik `database_sku`.

Voeg aan `main.tf` toe:

```hcl
resource "azurerm_mssql_database" "workshop" {
  name                 = "sqldb-jdoe-${var.environment}"
  server_id            = azurerm_mssql_server.workshop.id
  sku_name             = var.database_sku
  max_size_gb          = 2
  storage_account_type = "Local"
}
```

De juiste verwijzing is `azurerm_mssql_server.workshop.id`, niet de servernaam. Het databaseblok heeft geen `location` of `resource_group_name` nodig. `Basic`, 2 GB en lokale opslag vormen een kleine sandboxconfiguratie, geen productieadvies.

Voer `fmt`, `validate`, `plan` en `apply` met `acc.tfvars` uit. Als de server al bestaat, voegt het plan alleen de database toe. Wacht tot het aanmaken klaar is en herhaal het plan: **No changes**.

**Verwachte keten:** groep → server → database. Drie resources worden beheerd. De data source leest een bestaande identiteit; de systeemdatabase `master` is geen vierde gedeclareerde resource.

**Documentatie:** [SQL-database](https://registry.terraform.io/providers/hashicorp/azurerm/4.81.0/docs/resources/mssql_database).

## 4. Outputs, state en wijzigingen

**Doel:** inspecteer het resultaat, pas een kleine wijziging toe en herken een vervanging zonder die uit te voeren.

### `outputs.tf`

```hcl
output "resource_group_name" {
  description = "The workshop resource group name."
  value       = azurerm_resource_group.workshop.name
}

output "sql_server_fqdn" {
  description = "The SQL server hostname; SQL connectivity is deliberately not configured."
  value       = azurerm_mssql_server.workshop.fully_qualified_domain_name
}

output "database_name" {
  description = "The workshop database name."
  value       = azurerm_mssql_database.workshop.name
}
```

```shell
terraform apply "-var-file=acc.tfvars"
terraform output
terraform state list
```

De outputs tonen de groepsnaam, SQL-hostnaam en databasenaam. De verwachte statelijst bevat:

```text
data.azurerm_client_config.current
azurerm_resource_group.workshop
azurerm_mssql_server.workshop
azurerm_mssql_database.workshop
```

De weergavevolgorde kan verschillen. Een output maakt geen Azure-resource aan. De state bewaart de koppeling tussen Terraform-adressen en Azure-IDs; bewerk of deel deze niet.

### Antwoord: de tag toevoegen

Dit is het uiteindelijke groepsblok, zoals meegeleverd in de oplossing:

```hcl
resource "azurerm_resource_group" "workshop" {
  name     = "rg-terraform-db-workshop-jdoe"
  location = var.location

  tags = {
    environment = var.environment
    workshop    = "terraform"
    training    = "database" # Added in step 4; omit this line for the initial deployment.
  }
}
```

In een stapsgewijze demonstratie toont het plan een wijziging `~` aan de bestaande groep, zonder vernietiging. Pas toe met `acc.tfvars` en controleer daarna **No changes**. Heb je direct de volledige oplossing gedeployd, dan is de tag al aanwezig: verwijder deze, plan en pas toe met `acc.tfvars`, en voeg de tag opnieuw toe om de wijziging te tonen.

### Antwoord: `prd` vergelijken zonder toe te passen

```shell
terraform plan "-var-file=prd.tfvars"
```

`environment` verandert van `acc` naar `prd` en `database_sku` van `Basic` naar `S0`. De servernaam verandert, wat vervanging vereist. Ook de database die aan de vervangen server gekoppeld is, wordt beïnvloed. De groepsnaam blijft gelijk; de tag verandert. Het echte plan bepaalt de details en volgorde van de bewerkingen.

**Voer dit plan niet uit.** Beide bestanden gebruiken dezelfde state; `prd.tfvars` maakt niet automatisch een aparte omgeving. Ga terug naar het `acc`-plan:

```shell
terraform plan "-var-file=acc.tfvars"
```

**Antwoorden op de controle:** een verwijzing geeft een waarde door en maakt een afhankelijkheid; een `.tfvars`-bestand is geen aparte state en beschermt niet tegen vervangingen.

## 5. Opruimen

**Doel:** verwijder de drie tijdelijke resources zonder de state te verliezen.

```shell
terraform destroy "-var-file=acc.tfvars"
terraform state list
```

Bevestig pas nadat je het plan hebt gelezen. Terraform respecteert de afhankelijkheden in omgekeerde volgorde: database vóór server, dan de groep. De data source is geen identiteit die moet worden verwijderd. Na succes is de groep weg en de statelijst leeg.

De database kost geld, ook zonder queries: laat die na de sessie niet draaien. Bewaar bij een mislukte verwijdering de state en vraag hulp. Verwijder de state niet om de fout te verbergen.

**Onthoud:** een variabele definieert een invoer; een `.tfvars`-bestand geeft die een waarde; een verwijzing verbindt resources; de state koppelt je code aan de Azure-resources.
