variable "project" {
  default = "fvosbe-bachelor-thesis"
}

variable "region" {
  default = "europe-west1"
}

variable "gateway-image" {
  default = "gcr.io/endpoints-release/endpoints-runtime-serverless:2"
}

provider "google" {
  project     = var.project
  region      = var.region
  credentials = file("~/.gcp/fvosbe-bachelor-thesis.json")
}

// The database instance
resource "google_sql_database_instance" "postgres" {
  name             = "cloud-run-master-postgres"
  database_version = "POSTGRES_12"
  settings {
    tier = "db-f1-micro"
  }
}

// The Gateway Service
resource "google_cloud_run_service" "gateway" {
  name     = "gateway"
  location = var.region

  template {
    spec {
      containers {
        image = var.gateway-image
      }
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "1000"
        "run.googleapis.com/client-name"   = "terraform"
      }
    }
  }
  autogenerate_revision_name = true
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location = google_cloud_run_service.gateway.location
  project  = google_cloud_run_service.gateway.project
  service  = google_cloud_run_service.gateway.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

module hello-go-http-svc {
  source = "./cloud_run_service"

  project  = var.project
  location = var.region
  domain   = "thesis-gcp.frederikvosberg.de"

  # TODO add init_docker_images as null_resource
  # TODO add other depends_on
  database-instance = google_sql_database_instance.postgres
  gateway-host      = trimprefix(google_cloud_run_service.gateway.status[0].url, "https://")

  name          = "hello-gophers"
  config-prefix = "HELLO"
}

output gateway-url {
  value = google_cloud_run_service.gateway.status[0].url
}
