/******************************************
  Required variables
*******************************************/

variable "org_id" {
  description = "GCP Organization ID"
  type        = string
}

variable "billing_account" {
  description = "The ID of the billing account to associate projects with."
  type        = string
}

variable "group_org_admins" {
  description = "Google Group for GCP Organization Administrators"
  type        = string
}

variable "default_region" {
  description = "Default region to create resources where applicable."
  type        = string
  default     = "us-central1"
}

/******************************************
  Specific to CICD Project
*******************************************/

variable "gitlab_ci_subnetwork_cidr_range" {
  description = "The subnetwork to which the Gitlab CI Runner will be connected to (in CIDR range 0.0.0.0/0)"
  type        = string
}

variable "gitlab_group_path" {
  type = string
}

variable "gitlab_url" {
  type    = string
  default = "https://gitlab.com"
}

variable "gitlab_runner_name" {
  type    = string
  default = "gcp-cft-terraform"
}

variable "gitlab_runner_machine_type" {
  type    = string
  default = "e2-medium"
}

variable "gitlab_runner_machine_image" {
  type    = string
  default = "cos-cloud/global/images/family/cos-stable"
}

/******************************************
    Specific to Seed Project
*******************************************/

variable "seed_project" {
  description = "The Seed Project ID."
  type        = string
}

variable "terraform_sa_email" {
  description = "Email for terraform service account. It must be supplied by the seed project"
  type        = string
}

variable "terraform_sa_name" {
  description = "Fully-qualified name of the terraform service account. It must be supplied by the seed project"
  type        = string
}

variable "terraform_state_bucket" {
  description = "Default state bucket, used in Cloud Build substitutions. It must be supplied by the seed project"
  type        = string
}

/******************************************
  Optional variables
*******************************************/

variable "project_labels" {
  description = "Labels to apply to the project."
  type        = map(string)
  default     = {}
}

variable "project_prefix" {
  description = "Name prefix to use for projects created."
  type        = string
  default     = "cft"
}

variable "project_id" {
  description = "Custom project ID to use for project created."
  default     = ""
  type        = string
}

variable "activate_apis" {
  description = "List of APIs to enable in the Cloudbuild project."
  type        = list(string)

  default = [
    "serviceusage.googleapis.com",
    "servicenetworking.googleapis.com",
    "compute.googleapis.com",
    "logging.googleapis.com",
    "bigquery.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "cloudbilling.googleapis.com",
    "iam.googleapis.com",
    "admin.googleapis.com",
    "appengine.googleapis.com",
    "storage-api.googleapis.com"
  ]
}

variable "sa_enable_impersonation" {
  description = "Allow org_admins group to impersonate service account & enable APIs required."
  type        = bool
  default     = false
}

variable "service_account_prefix" {
  description = "Name prefix to use for service accounts."
  type        = string
  default     = "sa"
}

variable "folder_id" {
  description = "The ID of a folder to host this project"
  type        = string
  default     = ""
}
