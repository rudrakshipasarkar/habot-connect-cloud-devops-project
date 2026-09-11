# Candidate: Rudrakshi Pasarkar | Contact: rudrakshipasarkar@gmail.com
variable "project_id" {
  description = "Google Cloud project identifier for the staging environment."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid Google Cloud project identifier."
  }
}

variable "region" {
  description = "Region used for regional resources."
  type        = string
  default     = "me-central1"
}

variable "data_location" {
  description = "Shared location for Cloud Storage and BigQuery."
  type        = string
  default     = "ME-CENTRAL1"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "staging"
  validation {
    condition     = contains(["staging"], var.environment)
    error_message = "This blueprint intentionally permits only staging."
  }
}

variable "analyst_group_email" {
  description = "Google Group granted query access to UAE rows."
  type        = string
  sensitive   = true
  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.analyst_group_email))
    error_message = "analyst_group_email must be a valid email address."
  }
}

