# Candidate: Rudrakshi Pasarkar | Contact: rudrakshipasarkar@gmail.com
resource "google_service_account" "ingestion" {
  account_id   = "habot-stg-ingestion"
  display_name = "Habot staging ingestion"
  project      = var.project_id
}

resource "google_service_account" "analytics" {
  account_id   = "habot-stg-analytics"
  display_name = "Habot staging analytics"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "ingestion_writer" {
  bucket = google_storage_bucket.d0_raw_landing.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.ingestion.email}"
  condition {
    title       = "raw-prefix-only"
    description = "Restrict ingestion to the raw onboarding prefix."
    expression  = "resource.name.startsWith('projects/_/buckets/${google_storage_bucket.d0_raw_landing.name}/objects/onboarding/raw/')"
  }
}

resource "google_bigquery_dataset_iam_member" "ingestion_editor" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.d1_staged.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.ingestion.email}"
}

resource "google_project_iam_member" "ingestion_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.ingestion.email}"
}

resource "google_bigquery_dataset_iam_member" "analyst_viewer" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.d1_staged.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.analytics.email}"
}

resource "google_kms_crypto_key_iam_member" "service_account_decrypt" {
  for_each      = toset([google_service_account.ingestion.email, google_service_account.analytics.email])
  crypto_key_id = google_kms_crypto_key.data.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${each.value}"
}

locals {
  pubsub_service_agent   = "service-${data.google_project.current.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  bigquery_service_agent = "bq-${data.google_project.current.number}@bigquery-encryption.iam.gserviceaccount.com"
}

resource "google_bigquery_dataset_iam_member" "pubsub_writer" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.d1_staged.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${local.pubsub_service_agent}"
}

resource "google_storage_bucket_iam_member" "pubsub_raw_writer" {
  bucket = google_storage_bucket.d0_raw_landing.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${local.pubsub_service_agent}"
  condition {
    title       = "pubsub-raw-prefix-only"
    description = "Restrict the managed Pub/Sub writer to archived onboarding objects."
    expression  = "resource.name.startsWith('projects/_/buckets/${google_storage_bucket.d0_raw_landing.name}/objects/onboarding/raw/')"
  }
}

resource "google_pubsub_topic_iam_member" "dead_letter_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.dead_letter.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${local.pubsub_service_agent}"
}

resource "google_pubsub_subscription_iam_member" "dead_letter_subscriber" {
  project      = var.project_id
  subscription = google_pubsub_subscription.bigquery_sink.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:${local.pubsub_service_agent}"
}

resource "google_kms_crypto_key_iam_member" "managed_service_encryption" {
  for_each = toset([
    data.google_storage_project_service_account.gcs_account.email_address,
    local.pubsub_service_agent,
    local.bigquery_service_agent
  ])
  crypto_key_id = google_kms_crypto_key.data.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${each.value}"
  depends_on    = [google_project_service.required]
}
