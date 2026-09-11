# Candidate: Rudrakshi Pasarkar | Contact: rudrakshipasarkar@gmail.com
output "raw_bucket_name" { value = google_storage_bucket.d0_raw_landing.name }
output "bigquery_table" { value = "${var.project_id}.${google_bigquery_dataset.d1_staged.dataset_id}.${google_bigquery_table.student_onboarding.table_id}" }
output "validated_topic" { value = google_pubsub_topic.validated_onboarding.id }
output "ingestion_service_account" { value = google_service_account.ingestion.email }

