# Atelier Terraform sur Azure

**Objectif :** découvrir les ressources, références, variables, fichiers `.tfvars`, outputs et le cycle `plan → apply → destroy`.

**Corrigé formateur · 2 heures.** Les fichiers `.tf` de ce dossier forment la solution complète : trois ressources et une data source, sans réseau ni mot de passe SQL. Les étapes ci-dessous correspondent à l’exercice participant. `solution.html` contient le même corrigé en français et en néerlandais, consultable hors ligne.

## Préparation

**Objectif :** préparer une démonstration isolée dans la même sandbox.

Terraform, Azure CLI et un éditeur doivent être installés. Vérifiez avec `terraform version` et `az version`. Travaillez dans ce dossier, séparément de l’ancien atelier : ne réutilisez pas son state.

Azure CLI (`az`) fonctionne dans les deux terminaux. Connectez-vous et sélectionnez la sandbox avec le bloc adapté à votre terminal.

**Azure CLI dans Bash (Linux/macOS/WSL) :**

```bash
az login
az account set --subscription "<id-souscription-sandbox>"
az account show --output table
export ARM_SUBSCRIPTION_ID="$(az account show --query id --output tsv)"
```

**Azure CLI dans PowerShell (Windows) :**

```powershell
az login
az account set --subscription "<id-souscription-sandbox>"
az account show --output table
$env:ARM_SUBSCRIPTION_ID = (az account show --query id --output tsv)
```

Utilisez votre compte utilisateur Microsoft Entra avec `az login`, pas un service principal. Le formateur vérifie au préalable les droits de déploiement, la configuration de l’administrateur Entra et la disponibilité d’Azure SQL dans cette sandbox. Une autre souscription n’est pas nécessaire.

Remplacez `jdoe` par votre abréviation dans les noms Azure : **`rg-terraform-db-workshop-jdoe`** pour John Doe. Pour le serveur SQL, remplacez aussi `a1b2` par un suffixe personnel unique composé de lettres minuscules et de chiffres. Gardez ces mêmes valeurs pendant tout l’atelier.


**Attention :** ne déployez pas le corrigé et l’exercice avec les mêmes noms Azure et deux states différents. Utilisez une autre abréviation et un autre suffixe pour la démonstration, ou consultez simplement le corrigé sans le déployer. Ne copiez jamais de state entre les dossiers.

Le code livré contient déjà les variables, les trois ressources, les outputs et le tag final `training`. Pour une démonstration étape par étape, partez d’un dossier vide et ajoutez les blocs dans l’ordre ci-dessous. Pour exécuter directement la solution complète, après personnalisation des noms :

```shell
terraform init
terraform fmt
terraform validate
terraform plan "-var-file=acc.tfvars"
terraform apply "-var-file=acc.tfvars"
```

Ne lancez pas `apply` sans lire le plan. L’accès SQL est volontairement impossible : réseau public désactivé et aucun private endpoint. Le formateur vérifie avant la séance les droits SQL/Entra, l’enregistrement de `Microsoft.Sql`, la politique de la sandbox et la disponibilité de `Basic` dans `westeurope`. Ne demandez pas aux participants de résoudre ces prérequis pendant les deux heures.

## 1. Première ressource

**Objectif :** obtenir un premier plan avec un seul ajout, puis créer le groupe.

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

### `main.tf` à cette étape seulement

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

Commandes : `terraform init`, `terraform fmt`, `terraform validate`, `terraform plan`, `terraform apply`. N’utilisez pas encore les `.tfvars` : les variables ne sont pas déclarées. Une fois la création terminée, un deuxième plan indique **No changes**.

**À expliquer :** `azurerm_resource_group` est le type ; `workshop` est le label utilisé dans le code ; `name` est le nom Azure. Terraform ne crée pas une ressource par fichier : il lit ensemble tous les `.tf` du dossier.

## 2. Variables et fichiers `.tfvars`

**Objectif :** séparer la configuration des valeurs d’entrée.

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

Remplacez maintenant le bloc du groupe dans `main.tf` par :

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

### `acc.tfvars` — à déployer

```hcl
environment  = "acc"
location     = "westeurope"
database_sku = "Basic"
```

### `prd.tfvars` — plan uniquement

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

Les valeurs sont identiques à celles du premier déploiement : le plan doit indiquer **No changes**. `database_sku` est déjà déclarée mais ne sera utilisée qu’à l’étape 3.1. `environment` n’a pas de valeur par défaut : il faut fournir une valeur. Les autres variables ont un défaut, que le `.tfvars` peut remplacer.

## 3. Serveur SQL et références

**Objectif :** créer une dépendance implicite à partir de références, pas d’IDs copiés.

Ajoutez à `main.tf` le bloc suivant. La configuration Entra est fournie aux participants, pas à reconstruire pendant l’exercice :

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

Personnalisez le nom du serveur comme indiqué dans la préparation. La data source lit l’identité connectée ; le bloc Entra en fait l’administrateur SQL. `login_username` est un libellé et `object_id` identifie le compte. Aucun utilisateur, rôle ou mot de passe supplémentaire n’est créé.

Exécutez `fmt`, `validate`, `plan` et `apply` avec `acc.tfvars`. Si seul le groupe existait auparavant, le plan ajoute un serveur ; la lecture de la data source n’est pas un ajout de ressource.

**Réponse attendue :** `azurerm_resource_group.workshop.name` et `.location` relient le serveur au groupe. Terraform comprend qu’il doit créer le groupe en premier ; `depends_on` est inutile ici. Le serveur logique n’est pas une VM. L’accès public désactivé ne bloque pas la gestion par l’API Azure, mais empêche la connexion SQL depuis le poste.

**Documentation :** [serveur SQL](https://registry.terraform.io/providers/hashicorp/azurerm/4.81.0/docs/resources/mssql_server) · [configuration client](https://registry.terraform.io/providers/hashicorp/azurerm/4.81.0/docs/data-sources/client_config).

## 3.1 Base de données

**Objectif :** référencer l’ID du serveur et consommer `database_sku`.

Ajoutez à `main.tf` :

```hcl
resource "azurerm_mssql_database" "workshop" {
  name                 = "sqldb-jdoe-${var.environment}"
  server_id            = azurerm_mssql_server.workshop.id
  sku_name             = var.database_sku
  max_size_gb          = 2
  storage_account_type = "Local"
}
```

La référence correcte est `azurerm_mssql_server.workshop.id`, pas le nom du serveur. Aucun `location` ou `resource_group_name` n’est nécessaire dans le bloc de la base. `Basic`, 2 Go et le stockage local constituent une petite configuration de sandbox ; ce n’est pas une recommandation de production.

Exécutez `fmt`, `validate`, `plan` et `apply` avec `acc.tfvars`. Si le serveur existe déjà, le plan ajoute seulement la base. Attendez la fin de la création, puis répétez le plan : **No changes**.

**Chaîne attendue :** groupe → serveur → base. Trois ressources sont gérées. La data source lit une identité existante ; la base système `master` n’est pas une quatrième ressource déclarée.

**Documentation :** [base de données SQL](https://registry.terraform.io/providers/hashicorp/azurerm/4.81.0/docs/resources/mssql_database).

## 4. Outputs, state et modifications

**Objectif :** inspecter le résultat, appliquer un petit changement et reconnaître un remplacement sans l’exécuter.

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

Les valeurs des outputs sont le nom du groupe, le nom d’hôte SQL et le nom de la base. La liste de state attendue contient :

```text
data.azurerm_client_config.current
azurerm_resource_group.workshop
azurerm_mssql_server.workshop
azurerm_mssql_database.workshop
```

L’ordre d’affichage peut différer. Un output ne crée pas une ressource Azure. Le state mémorise les liens entre les adresses Terraform et les IDs Azure ; ne le modifiez pas et ne le partagez pas.

### Réponse : ajouter le tag

Voici le bloc final du groupe, tel qu’il est livré dans le corrigé :

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

Si vous suivez la démonstration progressive, le plan annonce une mise à jour `~` du groupe, sans destruction. Appliquez avec `acc.tfvars`, puis vérifiez **No changes**. Si vous avez déployé directement le corrigé complet, le tag est déjà présent : retirez-le, planifiez et appliquez avec `acc.tfvars`, puis ajoutez-le à nouveau pour montrer le changement.

### Réponse : comparer `prd` sans l’appliquer

```shell
terraform plan "-var-file=prd.tfvars"
```

`environment` passe de `acc` à `prd` et `database_sku` de `Basic` à `S0`. Le nom du serveur change, ce qui force son remplacement. La base liée au serveur remplacé est aussi affectée. Le nom du groupe reste stable ; son tag change. Le plan réel fait foi pour le détail et l’ordre des opérations.

**N’appliquez pas ce plan.** Les deux fichiers utilisent le même state ; `prd.tfvars` ne crée pas automatiquement un environnement séparé. Revenez au plan `acc` :

```shell
terraform plan "-var-file=acc.tfvars"
```

**Réponses au contrôle :** une référence transmet une valeur et crée une dépendance ; un fichier `.tfvars` ne constitue ni un state séparé ni une barrière contre les remplacements.

## 5. Nettoyage

**Objectif :** supprimer les trois ressources temporaires sans perdre le state.

```shell
terraform destroy "-var-file=acc.tfvars"
terraform state list
```

Confirmez uniquement après lecture du plan. Terraform respecte les dépendances en sens inverse : base avant serveur, puis groupe. La data source ne correspond pas à une identité à supprimer. Après succès, le groupe a disparu et la liste de state est vide.

La base coûte de l’argent même sans requêtes : ne la laissez pas tourner après la séance. Si une suppression échoue, gardez le state et demandez de l’aide. Ne supprimez pas le state pour masquer l’erreur.

**À retenir :** une variable déclare une entrée ; un `.tfvars` lui donne une valeur ; une référence relie des ressources ; le state associe votre code aux ressources Azure.
