# TODO clean up inputs

variable project {}

variable location {}

variable database-instance {
  type = object({
    name            = string
    connection_name = string
  })
}

variable base-url {
  type = string
}

resource "google_cloud_run_service" "kratos-public" {
  name     = "kratos-public"
  location = var.location

  depends_on = [
    var.database-instance,
    google_sql_database.service-db,
    google_sql_user.sql-user,
  ]

  template {
    spec {
      containers {
        image = "gcr.io/fvosbe-bachelor-thesis/kratos"

        env {
          name  = "SERVE_ADMIN_ENDPOINT"
          value = "false"
        }

        env {
          name  = "SERVE_ADMIN_BASE_URL"
          value = var.base-url
        }

        env {
          name  = "SERVE_PUBLIC_BASE_URL"
          value = "${var.base-url}/.ory/kratos/public/"
        }

        env {
          name = "DSN"
          #value = "postgres://${google_sql_user.sql-user.name}:${google_sql_user.sql-user.password}@/cloudsql/${var.database-instance.connection_name}/${google_sql_database.service-db.name}?sslmode=disable&max_conns=20&max_idle_conns=4"
          #value = "postgres://dbname=${google_sql_database.service-db.name} host=${var.database-instance.connection_name} user=${google_sql_user.sql-user.name} password=${google_sql_user.sql-user.name}"
          value = "postgres://${google_sql_user.sql-user.name}:${google_sql_user.sql-user.password}@:5432/${google_sql_database.service-db.name}?host=/cloudsql/${var.database-instance.connection_name}"
        }
        # TODO
        env {
          name  = "LOG_LEVEL"
          value = "debug"
        }

        env {
          name  = "URLS_LOGIN_UI"
          value = "${var.base-url}/auth/login"
        }

        env {
          name  = "URLS_REGISTRATION_UI"
          value = "${var.base-url}/auth/registration"
        }

        # TODO without skip_ssl_verify
        # TODO provider agnostic account
        env {
          name  = "COURIER_SMTP_CONNECTION_URI"
          value = "smtps://noreply%40aws-thesis.frederikvosberg.de:BachelorThesis2020@sslout.df.eu:465/?skip_ssl_verify=true"
        }

        env {
          name  = "URLS_WHITELISTED_RETURN_TO_URLS"
          value = var.base-url
        }

        env {
          name  = "SELFSERVICE_DEFAULT_BROWSER_RETURN_URL"
          value = var.base-url
        }

        env {
          name  = "SELFSERVICE_WHITELISTED_RETURN_URLS"
          value = var.base-url
        }

        env {
          name  = "SELFSERVICE_FLOWS_REGISTRATION_UI_URL"
          value = "${var.base-url}/auth/registration"
        }

        env {
          name  = "SELFSERVICE_FLOWS_LOGIN_UI_URL"
          value = "${var.base-url}/auth/login"
        }

        env {
          name  = "SELFSERVICE_FLOWS_LOGOUT_AFTER_DEFAULT_BROWSER_RETURN_URL"
          value = "${var.base-url}/auth/login"
        }

        env {
          name  = "SELFSERVICE_FLOWS_RECOVERY_UI_URL"
          value = "${var.base-url}/recovery"
        }

        env {
          name  = "SELFSERVICE_FLOWS_VERIFICATION_UI_URL"
          value = "${var.base-url}/recovery"
        }

        env {
          name  = "SELFSERVICE_FLOWS_VERIFICATION_AFTER_DEFAULT_BROWSER_RETURN_URL"
          value = var.base-url
        }

        env {
          name  = "SELFSERVICE_FLOWS_SETTINGS_UI_URL"
          value = "${var.base-url}/settings"
        }

      }
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"      = "1000"
        "run.googleapis.com/cloudsql-instances" = "${var.project}:europe-west1:${var.database-instance.name}"
        "run.googleapis.com/client-name"        = "terraform"
      }
    }
  }
  autogenerate_revision_name = true
}


resource "google_cloud_run_service" "kratos-admin" {
  name     = "kratos-admin"
  location = var.location

  depends_on = [
    var.database-instance,
    google_sql_database.service-db,
    google_sql_user.sql-user,
  ]

  template {
    spec {
      containers {
        image = "gcr.io/fvosbe-bachelor-thesis/kratos"

        env {
          name  = "SERVE_ADMIN_ENDPOINT"
          value = "true"
        }

        env {
          name  = "SERVE_ADMIN_BASE_URL"
          value = var.base-url
        }

        env {
          name  = "SERVE_PUBLIC_BASE_URL"
          value = "${var.base-url}/.ory/kratos/public/"
        }

        env {
          name = "DSN"
          #value = "postgres://${google_sql_user.sql-user.name}:${google_sql_user.sql-user.password}@/cloudsql/${var.database-instance.connection_name}/${google_sql_database.service-db.name}?sslmode=disable&max_conns=20&max_idle_conns=4"
          #value = "postgres://dbname=${google_sql_database.service-db.name} host=${var.database-instance.connection_name} user=${google_sql_user.sql-user.name} password=${google_sql_user.sql-user.name}"
          value = "postgres://${google_sql_user.sql-user.name}:${google_sql_user.sql-user.password}@:5432/${google_sql_database.service-db.name}?host=/cloudsql/${var.database-instance.connection_name}"
        }
        # TODO
        env {
          name  = "LOG_LEVEL"
          value = "debug"
        }

        env {
          name  = "URLS_LOGIN_UI"
          value = "${var.base-url}/auth/login"
        }

        env {
          name  = "URLS_REGISTRATION_UI"
          value = "${var.base-url}/auth/registration"
        }

        # TODO without skip_ssl_verify
        # TODO provider agnostic account
        env {
          name  = "COURIER_SMTP_CONNECTION_URI"
          value = "smtps://noreply%40aws-thesis.frederikvosberg.de:BachelorThesis2020@sslout.df.eu:465/?skip_ssl_verify=true"
        }

        env {
          name  = "URLS_WHITELISTED_RETURN_TO_URLS"
          value = var.base-url
        }

        env {
          name  = "SELFSERVICE_DEFAULT_BROWSER_RETURN_URL"
          value = var.base-url
        }

        env {
          name  = "SELFSERVICE_WHITELISTED_RETURN_URLS"
          value = var.base-url
        }

        env {
          name  = "SELFSERVICE_FLOWS_REGISTRATION_UI_URL"
          value = "${var.base-url}/auth/registration"
        }

        env {
          name  = "SELFSERVICE_FLOWS_LOGIN_UI_URL"
          value = "${var.base-url}/auth/login"
        }

        env {
          name  = "SELFSERVICE_FLOWS_LOGOUT_AFTER_DEFAULT_BROWSER_RETURN_URL"
          value = "${var.base-url}/auth/login"
        }

        env {
          name  = "SELFSERVICE_FLOWS_RECOVERY_UI_URL"
          value = "${var.base-url}/recovery"
        }

        env {
          name  = "SELFSERVICE_FLOWS_VERIFICATION_UI_URL"
          value = "${var.base-url}/recovery"
        }

        env {
          name  = "SELFSERVICE_FLOWS_VERIFICATION_AFTER_DEFAULT_BROWSER_RETURN_URL"
          value = var.base-url
a       }

        env {
          name  = "SELFSERVICE_FLOWS_SETTINGS_UI_URL"
          value = "${var.base-url}/settings"
        }

      }
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"      = "1000"
        "run.googleapis.com/cloudsql-instances" = "${var.project}:europe-west1:${var.database-instance.name}"
        "run.googleapis.com/client-name"        = "terraform"
      }
    }
  }
  autogenerate_revision_name = true
}

resource "google_sql_user" "sql-user" {
  instance = var.database-instance.name
  name     = "kratos-user"
  password = random_password.sql-user-password.result

  depends_on = [
    random_password.sql-user-password,
    var.database-instance,
  ]
}

resource "random_password" "sql-user-password" {
  length  = 16
  special = false
  // TODO allow special?
}

// The actual database (aka which holds the tables) in the database instance
resource "google_sql_database" "service-db" {
  instance = var.database-instance.name
  name     = "kratos"

  depends_on = [var.database-instance]
}


data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth-pub" {
  location = google_cloud_run_service.kratos-public.location
  project  = google_cloud_run_service.kratos-public.project
  service  = google_cloud_run_service.kratos-public.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

resource "google_cloud_run_service_iam_policy" "noauth-admin" {
  location = google_cloud_run_service.kratos-admin.location
  project  = google_cloud_run_service.kratos-admin.project
  service  = google_cloud_run_service.kratos-admin.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

output public-endpoint {
  value = "${google_cloud_run_service.kratos-public.status[0].url}:443"
}

output admin-endpoint {
  value = "${google_cloud_run_service.kratos-admin.status[0].url}:443"
}
