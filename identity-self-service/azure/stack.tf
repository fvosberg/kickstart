provider "azurerm" {
  # The "feature" block is required for AzureRM provider 2.x.
  # If you are using version 1.x, the "features" block is not allowed.
  version = "~>2.0"
  features {}
}

variable kratos-image {
  type = string
}

variable kratos-ui-image {
  type = string
}

variable acr-password {
  type = string
}

resource "azurerm_resource_group" "thesis" {
  name     = "thesis"
  location = "West Europe"
}

resource "azurerm_container_group" "kratos-ui" {
  name                = "kratos-ui"
  location            = azurerm_resource_group.thesis.location
  resource_group_name = azurerm_resource_group.thesis.name

  ip_address_type = "public"
  dns_name_label  = "kratos-ui-thesis"
  os_type         = "Linux"

  image_registry_credential {
    server   = "thesis.azurecr.io"
    username = "thesis"
    password = var.acr-password
  }


  container {
    name   = "kratos-ui"
    image  = var.kratos-ui-image
    cpu    = "0.25"
    memory = "0.5"

    ports {
      port     = 80
      protocol = "TCP"
    }

    environment_variables = {
      PORT              = "80"
      BASE_URL          = "http://kratos-ui-thesis.westeurope.azurecontainer.io"
      SECURITY_MODE     = "cookie"
      KRATOS_ADMIN_URL  = "http://kratos-thesis.westeurope.azurecontainer.io:4434"
      KRATOS_PUBLIC_URL = "http://kratos-thesis.westeurope.azurecontainer.io:4455"
    }
  }

  tags = {
    environment = "testing"
  }
}

resource "azurerm_container_group" "kratos" {
  name                = "kratos"
  location            = azurerm_resource_group.thesis.location
  resource_group_name = azurerm_resource_group.thesis.name

  # TODO private?
  ip_address_type = "public"
  dns_name_label  = "kratos-thesis"
  os_type         = "Linux"

  image_registry_credential {
    server   = "thesis.azurecr.io"
    username = "thesis"
    password = var.acr-password
  }


  container {
    name   = "kratos"
    image  = var.kratos-image
    cpu    = "1"
    memory = "0.5"

    ports {
      port     = 4455
      protocol = "TCP"
    }

    ports {
      port     = 4434
      protocol = "TCP"
    }

    environment_variables = {
      SERVE_ADMIN_PORT      = "4434"
      SERVE_ADMIN_BASE_URL  = "http://kratos-thesis.westeurope.azurecontainer.io"
      SERVE_PUBLIC_PORT     = "4455"
      SERVE_PUBLIC_BASE_URL = "http://kratos-ui-thesis.westeurope.azurecontainer.io/.ory/kratos/public/"
      DSN                   = "postgres://psqladminun%40main-postgres:H%40Sh1CoR3%21@main-postgres.postgres.database.azure.com:5432/kratos"
      # TODO
      LOG_LEVEL            = "debug"
      URLS_LOGIN_UI        = "http://kratos-ui-thesis.westeurope.azurecontainer.io/auth/login"
      URLS_REGISTRATION_UI = "http://kratos-ui-thesis.westeurope.azurecontainer.io/auth/registration"
      # TODO with skip_ssl_verify?
      COURIER_SMTP_CONNECTION_URI                                     = "smtps://noreply%40aws-thesis.frederikvosberg.de:BachelorThesis2020@sslout.df.eu:465"
      URLS_WHITELISTED_RETURN_TO_URLS                                 = "http://kratos-ui-thesis.westeurope.azurecontainer.io"
      SELFSERVICE_DEFAULT_BROWSER_RETURN_URL                          = "http://kratos-ui-thesis.westeurope.azurecontainer.io"
      SELFSERVICE_WHITELISTED_RETURN_URLS                             = "http://kratos-ui-thesis.westeurope.azurecontainer.io"
      SELFSERVICE_FLOWS_REGISTRATION_UI_URL                           = "http://kratos-ui-thesis.westeurope.azurecontainer.io/auth/registration"
      SELFSERVICE_FLOWS_LOGIN_UI_URL                                  = "http://kratos-ui-thesis.westeurope.azurecontainer.io/auth/login"
      SELFSERVICE_FLOWS_LOGOUT_AFTER_DEFAULT_BROWSER_RETURN_URL       = "http://kratos-ui-thesis.westeurope.azurecontainer.io/auth/login"
      SELFSERVICE_FLOWS_RECOVERY_UI_URL                               = "http://kratos-ui-thesis.westeurope.azurecontainer.io/recovery"
      SELFSERVICE_FLOWS_VERIFICATION_UI_URL                           = "http://kratos-ui-thesis.westeurope.azurecontainer.io/recovery"
      SELFSERVICE_FLOWS_VERIFICATION_AFTER_DEFAULT_BROWSER_RETURN_URL = "http://kratos-ui-thesis.westeurope.azurecontainer.io"
      SELFSERVICE_FLOWS_SETTINGS_UI_URL                               = "http://kratos-ui-thesis.westeurope.azurecontainer.io/settings"
    }
  }

  tags = {
    environment = "testing"
  }
}

resource "azurerm_postgresql_server" "main-postgres" {
  name                = "main-postgres"
  location            = azurerm_resource_group.thesis.location
  resource_group_name = azurerm_resource_group.thesis.name

  sku_name = "B_Gen5_1"

  storage_mb                   = 5120
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true

  administrator_login          = "psqladminun"
  administrator_login_password = "H@Sh1CoR3!"
  version                      = "11"
  ssl_enforcement_enabled      = true
}

resource "azurerm_postgresql_database" "kratos" {
  name                = "kratos"
  resource_group_name = azurerm_resource_group.thesis.name
  server_name         = azurerm_postgresql_server.main-postgres.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

resource "azurerm_postgresql_firewall_rule" "allow-azure-services" {
  name                = "allow-azure-services"
  resource_group_name = azurerm_resource_group.thesis.name
  server_name         = azurerm_postgresql_server.main-postgres.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}
