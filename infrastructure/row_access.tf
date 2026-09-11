# Candidate: Rudrakshi Pasarkar | Contact: rudrakshipasarkar@gmail.com
resource "google_bigquery_row_access_policy" "uae_analysts" {
  project          = var.project_id
  dataset_id       = google_bigquery_dataset.d1_staged.dataset_id
  table_id         = google_bigquery_table.student_onboarding.table_id
  policy_id        = "uae_analyst_rows"
  filter_predicate = "learner_region = 'UAE'"
  grantees = [
    "group:${var.analyst_group_email}",
    "serviceAccount:${google_service_account.analytics.email}"
  ]
}

