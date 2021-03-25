/*************************************************
  Bootstrap GCP Organization.
*************************************************/
locals {
  parent = var.parent_folder != "" ? "folders/${var.parent_folder}" : "organizations/${var.org_id}"
  org_admins_org_iam_permissions = [ "roles/orgpolicy.policyAdmin", "roles/resourcemanager.organizationAdmin", "roles/billing.user", "roles/billing.viewer"]
}

resource "google_folder" "bootstrap" {
  display_name = "fldr-bootstrap"
  parent       = local.parent
}

module "seed_bootstrap" {
  source                         = "terraform-google-modules/bootstrap/google"
  version                        = "~> 2.1"
  org_id                         = var.org_id
  folder_id                      = google_folder.bootstrap.id
  billing_account                = var.billing_account
  project_prefix                 = "cft"
  group_org_admins               = var.group_org_admins
  group_billing_admins           = var.group_billing_admins
  default_region                 = var.default_region
  org_project_creators           = var.org_project_creators
  sa_enable_impersonation        = true
  parent_folder                  = var.parent_folder == "" ? "" : local.parent
  org_admins_org_iam_permissions = local.org_admins_org_iam_permissions

  activate_apis = [
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
    "storage-api.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "securitycenter.googleapis.com",
    "accesscontextmanager.googleapis.com",
    "billingbudgets.googleapis.com",
    "cloudkms.googleapis.com"
  ]

  sa_org_iam_permissions = [
    "roles/accesscontextmanager.policyAdmin",
    "roles/billing.user",
    "roles/compute.networkAdmin",
    "roles/compute.xpnAdmin",
    "roles/iam.securityAdmin",
    "roles/iam.serviceAccountAdmin",
    "roles/logging.configWriter",
    "roles/orgpolicy.policyAdmin",
    "roles/resourcemanager.projectCreator",
    "roles/resourcemanager.folderAdmin",
    "roles/securitycenter.notificationConfigEditor",
    "roles/resourcemanager.organizationViewer"
  ]
}

module "gitlab_ci_bootstrap" {
  source                          = "./modules/gitlab"
  org_id                          = var.org_id
  folder_id                       = google_folder.bootstrap.id
  billing_account                 = var.billing_account
  project_prefix                  = "cft"
  group_org_admins                = var.group_org_admins
  default_region                  = var.default_region
  seed_project                    = module.seed_bootstrap.seed_project_id
  terraform_sa_email              = module.seed_bootstrap.terraform_sa_email
  terraform_sa_name               = module.seed_bootstrap.terraform_sa_name
  terraform_state_bucket          = module.seed_bootstrap.gcs_bucket_tfstate
  gitlab_ci_subnetwork_cidr_range = var.gitlab_ci_subnetwork_cidr_range
  gitlab_group_path               = var.gitlab_group_path
}