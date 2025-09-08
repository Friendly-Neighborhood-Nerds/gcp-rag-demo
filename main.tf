resource "google_project_service" "apis" {
  for_each = toset([
    "run.googleapis.com",
    "aiplatform.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ])
  project = var.project_id
  service = each.key
}

resource "google_cloud_run_service" "langchain_service" {
  name     = "langchain-vertexai"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.cloud_run_sa.email
      containers {
        image = "${google_artifact_registry_repository.langchain_repo.registry_uri}/chatbot-service:latest"
        resources {
          limits = {
            memory = "2Gi"
            "cpu"    = "1000m"
          }
        }
        ports {
          container_port = 8080
        }
        env {
          name  = "BUCKET_NAME"
          value = google_storage_bucket.docs.name
        }

        env {
          name  = "GOOGLE_CLOUD_PROJECT"
          value = var.project_id
        }

      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true

  depends_on = [google_project_service.apis]
}

resource "google_artifact_registry_repository" "langchain_repo" {
  provider      = google
  project       = var.project_id
  location      = var.region
  repository_id = "langchain-vertexai"
  format        = "DOCKER"
  description   = "Docker repo for LangChain Vertex AI PoC"
}

resource "google_storage_bucket" "docs" {
  name          = "docs-studer-${random_id.bucket_suffix.hex}"
  location      = "EU"
  force_destroy = true

  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "picture" {
  for_each = toset(fileset("${path.module}/samples", "*"))

  name   = each.value
  source = "${path.module}/samples/${each.value}"
  bucket = google_storage_bucket.docs.name
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}
