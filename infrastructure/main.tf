# Candidate: Rudrakshi Pasarkar | Contact: rudrakshipasarkar@gmail.com
locals {
  name_prefix = "habot-${var.environment}"
  labels = {
    environment = var.environment
    managed_by  = "terraform"
    data_class  = "confidential"
  }
}

data "google_project" "current" {
  project_id = var.project_id
}

data "google_storage_project_service_account" "gcs_account" {
  project = var.project_id
}

resource "google_project_service" "required" {
  for_each = toset([
    "appengine.googleapis.com",
    "bigquery.googleapis.com",
    "cloudkms.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com"
  ])
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_kms_key_ring" "data" {
  name       = "${local.name_prefix}-data"
  location   = var.region
  depends_on = [google_project_service.required]
}

resource "google_kms_crypto_key" "data" {
  name            = "student-onboarding"
  key_ring        = google_kms_key_ring.data.id
  rotation_period = "7776000s"
  lifecycle { prevent_destroy = true }
}

resource "google_storage_bucket" "d0_raw_landing" {
  name                        = "${var.project_id}-${local.name_prefix}-d0-raw"
  project                     = var.project_id
  location                    = var.data_location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false
  labels                      = local.labels

  encryption { default_kms_key_name = google_kms_crypto_key.data.id }
  versioning { enabled = true }
  retention_policy {
    retention_period = 2592000
    is_locked        = false
  }
  lifecycle_rule {
    condition { age = 90 }
    action { type = "Delete" }
  }
  depends_on = [google_kms_crypto_key_iam_member.managed_service_encryption]
}

resource "google_bigquery_dataset" "d1_staged" {
  dataset_id                 = "d1_staged_enforced"
  project                    = var.project_id
  location                   = var.data_location
  description                = "Validated student onboarding records."
  delete_contents_on_destroy = false
  default_encryption_configuration { kms_key_name = google_kms_crypto_key.data.id }
  labels     = local.labels
  depends_on = [google_kms_crypto_key_iam_member.managed_service_encryption]
}

resource "google_bigquery_table" "student_onboarding" {
  dataset_id          = google_bigquery_dataset.d1_staged.dataset_id
  table_id            = "student_onboarding"
  project             = var.project_id
  deletion_protection = true
  schema              = file("${path.module}/../schemas/bigquery_student_onboarding.json")
  time_partitioning {
    type  = "DAY"
    field = "submitted_at"
  }
  clustering = ["learner_region", "support_required"]
  labels     = local.labels
}

resource "google_pubsub_topic" "validated_onboarding" {
  name                       = "${local.name_prefix}-validated-onboarding"
  project                    = var.project_id
  message_retention_duration = "604800s"
  kms_key_name               = google_kms_crypto_key.data.id
  depends_on                 = [google_project_service.required, google_kms_crypto_key_iam_member.managed_service_encryption]
}

resource "google_pubsub_subscription" "bigquery_sink" {
  name                       = "${local.name_prefix}-bigquery-sink"
  project                    = var.project_id
  topic                      = google_pubsub_topic.validated_onboarding.id
  message_retention_duration = "604800s"
  retain_acked_messages      = true
  ack_deadline_seconds       = 60
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }
  bigquery_config {
    table               = "${var.project_id}.${google_bigquery_dataset.d1_staged.dataset_id}.${google_bigquery_table.student_onboarding.table_id}"
    use_table_schema    = true
    write_metadata      = false
    drop_unknown_fields = false
  }
  depends_on = [google_bigquery_dataset_iam_member.pubsub_writer]
}

resource "google_pubsub_subscription" "raw_archive" {
  name                       = "${local.name_prefix}-raw-archive"
  project                    = var.project_id
  topic                      = google_pubsub_topic.validated_onboarding.id
  message_retention_duration = "604800s"
  ack_deadline_seconds       = 60
  cloud_storage_config {
    bucket          = google_storage_bucket.d0_raw_landing.name
    filename_prefix = "onboarding/raw/"
    filename_suffix = ".jsonl"
    max_duration    = "300s"
    max_bytes       = 1000000
  }
  depends_on = [google_storage_bucket_iam_member.pubsub_raw_writer]
}

resource "google_pubsub_topic" "dead_letter" {
  name         = "${local.name_prefix}-dead-letter"
  project      = var.project_id
  kms_key_name = google_kms_crypto_key.data.id
  depends_on   = [google_kms_crypto_key_iam_member.managed_service_encryption]
}
