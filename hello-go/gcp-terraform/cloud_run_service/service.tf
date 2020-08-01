# TODO clean up inputs

variable project {}

variable name {}

variable config-prefix {}

variable location {}

variable database-instance {
  type = object({
    name            = string
    connection_name = string
  })
}

variable domain {
  type = string
}

variable gateway-host {
  type = string
}

data "google_container_registry_image" "image" {
  name = var.name
}

resource "google_cloud_run_service" "service" {
  name     = var.name
  location = var.location

  depends_on = [
    var.database-instance,
    google_sql_database.service-db,
    google_sql_user.sql-user,
  ]

  template {
    spec {
      containers {
        image = "gcr.io/fvosbe-bachelor-thesis/hello-go"

        env {
          name  = "${var.config-prefix}_POSTGRES_HOST"
          value = "/cloudsql/${var.database-instance.connection_name}"
        }

        env {
          name  = "${var.config-prefix}_POSTGRES_DB"
          value = google_sql_database.service-db.name
        }

        env {
          name  = "${var.config-prefix}_POSTGRES_USER"
          value = google_sql_user.sql-user.name
        }

        env {
          name  = "${var.config-prefix}_POSTGRES_PASSWORD"
          value = google_sql_user.sql-user.password
        }

        #env {
        #name  = "${var.config-prefix}_BASE_PATH"
        #value = var.name
        #        }
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
  name     = "${var.name}-user"
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
  name     = var.name

  depends_on = [var.database-instance]
}



resource "google_endpoints_service" "rest-endpoint-gateway" {
  # TODO hast has to be gateway host and service_name has to be the same as the host
  # => does that mean, that I can just have one google_endpoints_service for all my services?
  service_name = var.gateway-host
  project      = var.project
  depends_on   = [google_cloud_run_service.service]

  openapi_config = <<EOF
swagger: '2.0'
info:
  title: '${var.name} service endpoints'
  version: 1.0.0
host: ${var.gateway-host}
basePath: /${var.name}
schemes:
  - https
produces:
  - application/json
x-google-backend:
  address: ${google_cloud_run_service.service.status[0].url}
  protocol: h2
paths:
  /greetings:
    get:
      summary: Get greetings
      operationId: hello-gophers-list-greetings
      responses:
        '200':
          description: A list of the greetings
          schema:
            type: string
    post:
      summary: Create Greeting
      operationId: hello-gophers-create-greetings
      responses:
        '201':
          description: Successful created a greeting
          schema:
            type: string
EOF
}

# TODO path mappings should not be implemented in this module, but provided as input

resource "null_resource" "gateway_image" {
  triggers = {
    image_id = google_endpoints_service.rest-endpoint-gateway.config_id
  }

  depends_on = [google_endpoints_service.rest-endpoint-gateway]

  provisioner "local-exec" {

    command = <<EOF
./build_esp_image.sh \
	-s "${var.gateway-host}" \
	-c ${google_endpoints_service.rest-endpoint-gateway.config_id} \
	-p  ${var.project}
EOF

  }
}



# TODO auth to ensure just traffic via ESP

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location = google_cloud_run_service.service.location
  project  = google_cloud_run_service.service.project
  service  = google_cloud_run_service.service.name

  policy_data = data.google_iam_policy.noauth.policy_data
}


# TODO clean up outputs
output url {
  value = google_cloud_run_service.service.status[0].url
}

output endpoint {
  value = "${trimprefix(google_cloud_run_service.service.status[0].url, "https://")}:443"
}

output gateway-url {
  value = google_endpoints_service.rest-endpoint-gateway.dns_address
}

output gateway-endpoints {
  value = google_endpoints_service.rest-endpoint-gateway.endpoints
}

output service-name {
  value = google_cloud_run_service.service.name
}
