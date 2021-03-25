locals {
  cicd_project_name           = format("%s-%s", var.project_prefix, "cicd")
  impersonation_enabled_count = var.sa_enable_impersonation ? 1 : 0
  activate_apis               = distinct(concat(var.activate_apis, ["billingbudgets.googleapis.com"]))
  gitlab_ci_agent_iam_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/compute.instanceAdmin.v1",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin"
  ]
  gitlab_ci_runner_iam_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ]
}

data "gitlab_group" "base" {
  full_path = var.gitlab_group_path
}

resource "gitlab_group_variable" "terraform_service_account" {
  group     = data.gitlab_group.base.id
  key       = "TF_VAR_terraform_service_account"
  value     = var.terraform_sa_email
  protected = false
  masked    = true
}

resource "gitlab_group_variable" "seed_project" {
  group     = data.gitlab_group.base.id
  key       = "TF_VAR_seed_project"
  value     = var.seed_project
  protected = false
  masked    = true
}

resource "gitlab_group_variable" "org_id" {
  group     = data.gitlab_group.base.id
  key       = "TF_VAR_org_id"
  value     = var.org_id
  protected = false
  masked    = true
}

resource "gitlab_group_variable" "billing_account" {
  group     = data.gitlab_group.base.id
  key       = "TF_VAR_billing_account"
  value     = var.billing_account
  protected = false
  masked    = true
}

/******************************************
  CICD project
*******************************************/

module "cicd_project" {
  source                      = "terraform-google-modules/project-factory/google"
  version                     = "~> 10.1.0"
  name                        = local.cicd_project_name
  random_project_id           = true
  disable_services_on_destroy = false
  folder_id                   = var.folder_id
  org_id                      = var.org_id
  billing_account             = var.billing_account
  activate_apis               = local.activate_apis
  labels                      = var.project_labels
  create_project_sa           = false
}

data "google_compute_zones" "available" {
  project = module.cicd_project.project_id
  region  = var.default_region
}

resource "google_service_account" "gitlab_ci_agent_sa" {
  project      = module.cicd_project.project_id
  account_id   = format("%s-gitlab-ci-agent", var.service_account_prefix)
  display_name = "Gitlab CI Agent Service Account"
}

resource "google_project_iam_member" "gitlab_ci_agent_project_iam" {
  project = module.cicd_project.project_id
  count   = length(local.gitlab_ci_agent_iam_roles)
  role    = element(local.gitlab_ci_agent_iam_roles, count.index)
  member  = "serviceAccount:${google_service_account.gitlab_ci_agent_sa.email}"
}

resource "google_service_account" "gitlab_ci_runner_sa" {
  project      = module.cicd_project.project_id
  account_id   = format("%s-gitlab-ci-runner", var.service_account_prefix)
  display_name = "Gitlab CI Runner Service Account"
}

resource "google_project_iam_member" "gitlab_ci_runner_project_iam" {
  project = module.cicd_project.project_id
  count   = length(local.gitlab_ci_runner_iam_roles)
  role    = element(local.gitlab_ci_runner_iam_roles, count.index)
  member  = "serviceAccount:${google_service_account.gitlab_ci_runner_sa.email}"
}

# Allow the GitLab CI Agent to use the Gitlab CI Runner service account.
resource "google_service_account_iam_member" "gitlab_ci_agent_runner_iam" {
  service_account_id = google_service_account.gitlab_ci_runner_sa.id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.gitlab_ci_agent_sa.email}"
}

# Allow the Gitlab CI Agent service account to impersonate the Terraform service account.
resource "google_service_account_iam_member" "agent_terraform_sa_impersonate_permissions" {
  service_account_id = var.terraform_sa_name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.gitlab_ci_agent_sa.email}"
}

# Required to allow the Gitlab CI Agent service account to access state with impersonation.
resource "google_storage_bucket_iam_member" "agent_state_iam" {
  bucket = var.terraform_state_bucket
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.gitlab_ci_agent_sa.email}"
}

# Allow the Gitlab CI Runner service account to impersonate the Terraform service account.
resource "google_service_account_iam_member" "runner_terraform_sa_impersonate_permissions" {
  service_account_id = var.terraform_sa_name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.gitlab_ci_runner_sa.email}"
}

# Required to allow the Gitlab CI Runner service account to access state with impersonation.
resource "google_storage_bucket_iam_member" "runner_state_iam" {
  bucket = var.terraform_state_bucket
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.gitlab_ci_runner_sa.email}"
}

resource "google_compute_network" "gitlab_ci" {
  project                 = module.cicd_project.project_id
  name                    = "vpc-b-gitlab-ci"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "gitlab_ci" {
  project       = module.cicd_project.project_id
  name          = "sb-b-gitlab-ci-${var.default_region}"
  ip_cidr_range = var.gitlab_ci_subnetwork_cidr_range
  region        = var.default_region
  network       = google_compute_network.gitlab_ci.self_link
}

resource "google_compute_firewall" "iap" {
  name    = "allow-iap-ssh"
  project = module.cicd_project.project_id
  network = google_compute_network.gitlab_ci.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  source_ranges = ["35.235.240.0/20"]
}

resource "google_compute_firewall" "docker_machine" {
  project     = module.cicd_project.project_id
  name        = "docker-machines"
  description = "Allow the Gitlab CI Agent to connect to the Gitlab CI Runners using SSH and Docker Machine"
  network     = google_compute_network.gitlab_ci.name
  source_tags = ["gitlab-runner"]
  target_tags = ["docker-machine"]
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["22", "2376"]
  }
}

resource "google_compute_router" "gitlab_ci" {
  name    = "cr-${google_compute_network.gitlab_ci.name}-${var.default_region}-nat-router"
  project = module.cicd_project.project_id
  region  = var.default_region
  network = google_compute_network.gitlab_ci.self_link
}

resource "google_compute_router_nat" "gitlab_ci" {
  project                            = module.cicd_project.project_id
  name                               = "rn-${google_compute_network.gitlab_ci.name}-${var.default_region}-egress"
  router                             = google_compute_router.gitlab_ci.name
  region                             = var.default_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

data "template_file" "runner_config" {
  template = file("${path.module}/templates/config.toml.tpl")

  vars = {
    project                = module.cicd_project.project_id
    zone                   = data.google_compute_zones.available.names[0]
    network                = google_compute_network.gitlab_ci.name
    subnetwork             = google_compute_subnetwork.gitlab_ci.name
    runner_name            = var.gitlab_runner_name
    runner_url             = var.gitlab_url
    runner_idle_count      = "0"
    runner_idle_time       = "60"
    runner_machine_type    = var.gitlab_runner_machine_type
    runner_machine_image   = var.gitlab_runner_machine_image
    runner_service_account = google_service_account.gitlab_ci_runner_sa.email
  }
}

data "template_file" "startup" {
  template = file("${path.module}/templates/startup.sh.tpl")

  vars = {
    project                   = module.cicd_project.project_id
    zone                      = data.google_compute_zones.available.names[0]
    network                   = google_compute_network.gitlab_ci.name
    subnetwork                = google_compute_subnetwork.gitlab_ci.name
    runner_name               = var.gitlab_runner_name
    runners_config            = data.template_file.runner_config.rendered
    runner_url                = var.gitlab_url
    runner_registration_token = data.gitlab_group.base.runners_token
    runner_service_account    = google_service_account.gitlab_ci_runner_sa.email
  }
}

data "template_file" "shutdown" {
  template = file("${path.module}/templates/shutdown.sh.tpl")

  vars = {
    runner_url = var.gitlab_url
  }
}

resource "google_compute_instance" "gitlab_ci" {
  count        = 1
  project      = module.cicd_project.project_id
  name         = format("gitlab-agent-%s", count.index + 1)
  machine_type = "e2-micro"
  zone         = data.google_compute_zones.available.names[0]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.gitlab_ci.id
  }

  tags = ["gitlab-runner"]

  metadata = {
    shutdown-script = data.template_file.shutdown.rendered
  }
  metadata_startup_script = data.template_file.startup.rendered

  service_account {
    email = google_service_account.gitlab_ci_agent_sa.email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  allow_stopping_for_update = true

  depends_on = [google_compute_router_nat.gitlab_ci]
}