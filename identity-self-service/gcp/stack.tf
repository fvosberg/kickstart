variable "project" {
  default = "fvosbe-bachelor-thesis"
}

variable "region" {
  default = "europe-west1"
}

provider "google" {
  project     = var.project
  region      = var.region
  credentials = file("~/.gcp/fvosbe-bachelor-thesis.json")
}

// The database instance
resource "google_sql_database_instance" "main-postgres" {
  name             = "cloud-run-main-postgres"
  database_version = "POSTGRES_12"
  settings {
    tier = "db-f1-micro"
  }
}

module kratos-svc {
  source   = "./kratos"
  location = var.region

  project           = var.project
  database-instance = google_sql_database_instance.main-postgres

  base-url = "https://thesis-gcp.frederikvosberg.de"
}

# TODO add depends_on workaround to modules

module kratos-ui-svc {
  source = "./kratos-ui"

  kratos-public-url = module.kratos-svc.public-endpoint
  kratos-admin-url  = module.kratos-svc.admin-endpoint
  location          = var.region
  domain            = "thesis-gcp.frederikvosberg.de"
}
