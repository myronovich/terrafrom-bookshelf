locals {
  project_id = "gcptf-320808"
}
#credentials
provider "google" {
  credentials = file("gcptf-320808-2497d5d6f7e0.json")
  project = "gcptf-320808"
  region  = "us-central1"
  zone    = "us-central1-c"
}

#single vm
resource "google_compute_instance" "my_vm" {
  name         = "tf-created-vm"
  machine_type = "f1-micro"
  tags         = ["web"]
  zone         = "us-central1-a"
  metadata_startup_script = file("startupscript.sh")
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-9"
    }
  }
  network_interface {
    network = "default"
    access_config {}
  }
  }

#firewall for allow http on 5100/8080
  resource "google_compute_firewall" "default" {
    name    = "tf-firewall"
    network = google_compute_network.default.name
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
  }

#storage for backend
resource "google_storage_bucket" "bucketforpythonapptm" {
  name          = "bucketforpythonapptm"
  location      = "US"
  force_destroy = true

  uniform_bucket_level_access = true
}

    resource "google_compute_instance_template" "tpl" {
      name         = "tf-python-template"
      machine_type = "f1-micro"
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
}
