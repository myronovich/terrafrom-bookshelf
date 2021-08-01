locals {
  project_id = "gcptf-320808"
}
#credentials
provider "google" {
  credentials = file("gcptf-320808-44a491339d5b.json")
}

#vars (move later into variables.tf)
################################
variable "region" {
  default = "us-central1"
}
variable "app_name" {
  default = "bookshelf"
}
variable "project" {
  default = "gcptf-320808"
}
################################



###firewall for allow http on 5100/8080
########################################
  resource "google_compute_firewall" "default" {
    name    = var.app_name
    network = "default"
    project = var.project
  allow {
      protocol = "icmp"
    }
  allow {
      protocol = "tcp"
      ports    = ["80", "8080", "1000-2000"]
    }
    source_tags = ["web"]
  }

  resource "google_compute_network" "default" {
    name         = "tf-network"
    routing_mode = "GLOBAL"
    project = var.project
  }
##########################################











###################storage for backend######################
resource "google_storage_bucket" "bucketforpythonapptm" {
  project       = var.project
  name          = "bucketforpythonapptm"
  location      = "US"
  force_destroy = true

  uniform_bucket_level_access = true
}
############################################################





##############instance template#######################
######################################################
resource "google_compute_instance_template" "tpl" {
    project      = var.project
    name         = "tf-python-template"
    machine_type = "f1-micro"
    tags = ["http-server","http-server"]
    metadata_startup_script = file("startupscript.sh")
    disk {
      source_image = "debian-cloud/debian-9"
      auto_delete  = true
      disk_size_gb = 10
      boot         = true
    }
    network_interface {
      network = "default"
      access_config {}
    }
    service_account {
  email  = "31714074129-compute@developer.gserviceaccount.com"
  scopes = ["cloud-platform"]
}
}

#####################################################






#####################################################
#######MYSQL INSTANCE################################
resource "google_sql_database_instance" "master" {
  name             = "bookshelf1"
  project      = var.project
  database_version = "MYSQL_5_6"
  region           = "us-central1"

  settings {
  tier = "db-g1-small"
  }
}

resource "google_sql_database" "database" {
  project  = var.project
  name     = "bookshelf1"
  instance = "bookshelf1"
}

####################################################

resource "google_compute_instance_group_manager" "appserver" {
  name = "igm"
  project = var.project
  base_instance_name = "bs-instance"
  zone               = "us-central1-a"

  version {
  instance_template  = "${google_compute_instance_template.tpl.self_link}"
  }

  target_size  = 2
  named_port {
    name = "custom"
    port = 5100
  }
}
################## As recomended: module approach for some resources #######
######                        NAT
module "cloud_router" {
  source  = "terraform-google-modules/cloud-router/google"
  version = "~> 0.4"
  project = var.project
  name    = "tf-created-router"
  network = "default"
  region  = var.region
  nats = [{
    name = "my-tfnat-gateway"
  }]
}

###################           LB
module "gce-lb-http" {
  source  = "GoogleCloudPlatform/lb-http/google"
  version = "~> 5.1"
  name    = "tf-createdlb"
  project = "gcptf-320808"
  target_tags = ["pythonappserver-igm"]

  backends = {
    default = {

      description                     = null
      protocol                        = "HTTP"
      port                            = 80
      port_name                       = "http"
      timeout_sec                     = 10
      connection_draining_timeout_sec = null
      enable_cdn                      = false
      security_policy                 = null
      session_affinity                = null
      affinity_cookie_ttl_sec         = null
      custom_request_headers          = null
      custom_response_headers         = null

      health_check = {
        check_interval_sec  = null
        timeout_sec         = null
        healthy_threshold   = null
        unhealthy_threshold = null
        request_path        = "/"
        port                = 80
        host                = null
        logging             = null
      }

      log_config = {
        enable      = true
        sample_rate = 1.0
      }

      groups = [
        {
          group                        = "igm"
          balancing_mode               = null
          capacity_scaler              = null
          description                  = null
          max_connections              = null
          max_connections_per_instance = null
          max_connections_per_endpoint = null
          max_rate                     = null
          max_rate_per_instance        = null
          max_rate_per_endpoint        = null
          max_utilization              = null
        },
          ]

      iap_config = {
        enable               = false
        oauth2_client_id     = ""
        oauth2_client_secret = ""
      }
    }
  }
}
