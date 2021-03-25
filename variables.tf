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

variable "group_billing_admins" {
  description = "Google Group for GCP Billing Administrators"
  type        = string
}

variable "default_region" {
  description = "Default region to create resources where applicable."
  type        = string
  default     = "europe-west1"
}

variable "parent_folder" {
  description = "Optional - if using a folder for testing."
  type        = string
  default     = ""
}

variable "org_project_creators" {
  description = "Additional list of members to have project creator role across the organization. Prefix of group: user: or serviceAccount: is required."
  type        = list(string)
  default     = []
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