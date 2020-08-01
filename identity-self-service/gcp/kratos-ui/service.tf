# TODO clean up inputs

variable location {}

variable domain {
  type = string
}

variable kratos-public-url {
  type = string
}

variable kratos-admin-url {
  type = string
}

resource "google_cloud_run_service" "kratos-ui" {
  name     = "kratos-ui"
  location = var.location

  template {
    spec {
      containers {
        image = "gcr.io/fvosbe-bachelor-thesis/kratos-ui"

        env {
          name  = "BASE_URL"
          value = "https://thesis-gcp.frederikvosberg.de"
        }

        env {
          name  = "SECURITY_MODE"
          value = "cookie"
        }

        env {
          name  = "KRATOS_ADMIN_URL"
          value = var.kratos-admin-url
        }

        env {
          name  = "KRATOS_PUBLIC_URL"
          value = var.kratos-public-url
        }
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
  location = google_cloud_run_service.kratos-ui.location
  project  = google_cloud_run_service.kratos-ui.project
  service  = google_cloud_run_service.kratos-ui.name

  policy_data = data.google_iam_policy.noauth.policy_data
}


# TODO clean up outputs
output url {
  value = google_cloud_run_service.kratos-ui.status[0].url
}

output endpoint {
  value = "${trimprefix(google_cloud_run_service.kratos-ui.status[0].url, "https://")}:443"
}

output service-name {
  value = google_cloud_run_service.kratos-ui.name
}
