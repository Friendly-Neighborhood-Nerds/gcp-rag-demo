resource "google_service_account" "cloud_run_sa" {
  account_id   = "cloud-run-langchain"
  display_name = "Cloud Run LangChain Service Account"
}

resource "google_project_iam_member" "vertex_ai_user" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_cloud_run_service_iam_member" "sa_invoker" {
  service  = google_cloud_run_service.langchain_service.name
  location = google_cloud_run_service.langchain_service.location
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_storage_bucket_iam_member" "bucket_reader" {
  bucket = google_storage_bucket.docs.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}
