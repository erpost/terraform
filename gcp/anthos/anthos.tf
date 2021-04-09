variable "ssh_location" {
  type = string
}

provider "google" {
  project = "interop2"
  region  = "us-central1"
}

# Enable Compute Engine API
resource "google_project_service" "compute" {
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

# Enable Anthos API
resource "google_project_service" "anthos" {
  service = "anthos.googleapis.com"

  disable_on_destroy = false
}

# Enable Anthos GKE API
resource "google_project_service" "anthosgke" {
  service = "anthosgke.googleapis.com"

  disable_on_destroy = false
}

# Enable Cloud Resource Manager API
resource "google_project_service" "cloudresourcemanager" {
  service = "cloudresourcemanager.googleapis.com"

  disable_on_destroy = false
}

# Enable Containers API
resource "google_project_service" "container" {
  service = "container.googleapis.com"

  disable_on_destroy = false
}

# Enable GKE Connect API
resource "google_project_service" "gkeconnect" {
  service = "gkeconnect.googleapis.com"

  disable_on_destroy = false
}

# Enable GKE Hub API
resource "google_project_service" "gkehub" {
  service = "gkehub.googleapis.com"

  disable_on_destroy = false
}

# Enable Service Usage API
resource "google_project_service" "serviceusage" {
  service = "serviceusage.googleapis.com"

  disable_on_destroy = false
}

# Enable Stackdriver API
resource "google_project_service" "stackdriver" {
  service = "stackdriver.googleapis.com"

  disable_on_destroy = false
}

# Enable Monitoring API
resource "google_project_service" "monitoring" {
  service = "monitoring.googleapis.com"

  disable_on_destroy = false
}

# Enable Logging API
resource "google_project_service" "logging" {
  service = "logging.googleapis.com"

  disable_on_destroy = false
}

# Create Service Account
resource "google_service_account" "baremetal-gcr" {
  account_id   = "baremetal-gcr-id"
  display_name = "baremetal-gcr"
}

# Add GKE Hub Connect Binding
resource "google_project_iam_binding" "gkehub" {
  role    = "roles/gkehub.connect"

  members = [
    "serviceAccount:${google_service_account.baremetal-gcr.email}",
  ]
}

# Add GKE Hub Admin Binding
resource "google_project_iam_binding" "gkehubadmin" {
  role    = "roles/gkehub.admin"

  members = [
    "serviceAccount:${google_service_account.baremetal-gcr.email}",
  ]
}

# Add Logging Writer Binding
resource "google_project_iam_binding" "logwriter" {
  role    = "roles/logging.logWriter"

  members = [
    "serviceAccount:${google_service_account.baremetal-gcr.email}",
  ]
}

# Add Metric Writer Binding
resource "google_project_iam_binding" "metricwriter" {
  role    = "roles/monitoring.metricWriter"

  members = [
    "serviceAccount:${google_service_account.baremetal-gcr.email}",
  ]
}

# Add Dashboard Editor Binding
resource "google_project_iam_binding" "dashboardeditor" {
  role    = "roles/monitoring.dashboardEditor"

  members = [
    "serviceAccount:${google_service_account.baremetal-gcr.email}",
  ]
}

# Add Stackdriver Writer Binding
resource "google_project_iam_binding" "stackdriverwriter" {
  role    = "roles/stackdriver.resourceMetadata.writer"

  members = [
    "serviceAccount:${google_service_account.baremetal-gcr.email}",
  ]
}

# Create VPC
resource "google_compute_network" "vpc_network" {
  name                    = "vpc-anthos"
  auto_create_subnetworks = false
}

# Create Subnetwork 1
resource "google_compute_subnetwork" "vpc_subnet_1" {
  name          = "subnet-anthos1"
  ip_cidr_range = "10.1.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.id
}

# Create Subnetwork 2
resource "google_compute_subnetwork" "vpc_subnet_2" {
  name          = "subnet-anthos2"
  ip_cidr_range = "10.2.0.0/16"
  region        = "us-east1"
  network       = google_compute_network.vpc_network.id
}

# Create Firewall Rule from Laptop
resource "google_compute_firewall" "full-access" {
  name     = "full-access"
  network  = google_compute_network.vpc_network.name
  priority = 100

  allow {
    protocol = "all"
  }

  source_ranges = [var.ssh_location]
}

# Create Firewall Rule for Internal VPC Traffic
resource "google_compute_firewall" "internal-access" {
  name     = "internal-access"
  network  = google_compute_network.vpc_network.name
  priority = 200

  allow {
    protocol = "all"
  }

  source_ranges = ["10.0.0.0/8"]
}

# Create Workstation Instance
resource "google_compute_instance" "abm-ws" {
  name         = "abm-ws"
  machine_type = "n1-standard-8"
  zone         = "us-central1-a"
  can_ip_forward = true
  min_cpu_platform = "Intel Haswell"

  boot_disk {
    initialize_params {
      image = "ubuntu-2004-lts"
      size = "200"
      type = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vpc_subnet_1.id

    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    project = "anthos"
  }
  metadata_startup_script = file("${path.module}/startup.sh")
}

# Create Control Plane Node 1
resource "google_compute_instance" "abm-cp1" {
  name         = "abm-cp1"
  machine_type = "n1-standard-8"
  zone         = "us-central1-a"
  can_ip_forward = true
  min_cpu_platform = "Intel Haswell"

  boot_disk {
    initialize_params {
      image = "ubuntu-2004-lts"
      size = "200"
      type = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vpc_subnet_1.id

    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    project = "anthos"
  }
  metadata_startup_script = file("${path.module}/startup.sh")
}

# Create Control Plane Node 2
resource "google_compute_instance" "abm-cp2" {
  name         = "abm-cp2"
  machine_type = "n1-standard-8"
  zone         = "us-central1-a"
  can_ip_forward = true
  min_cpu_platform = "Intel Haswell"

  boot_disk {
    initialize_params {
      image = "ubuntu-2004-lts"
      size = "200"
      type = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vpc_subnet_1.id

    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    project = "anthos"
  }
  metadata_startup_script = file("${path.module}/startup.sh")
}

# Create Control Plane Node 3
resource "google_compute_instance" "abm-cp3" {
  name         = "abm-cp3"
  machine_type = "n1-standard-8"
  zone         = "us-central1-a"
  can_ip_forward = true
  min_cpu_platform = "Intel Haswell"

  boot_disk {
    initialize_params {
      image = "ubuntu-2004-lts"
      size = "200"
      type = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vpc_subnet_1.id

    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    project = "anthos"
  }
    metadata_startup_script = file("${path.module}/startup.sh")
}

# Create Worker Node 1
resource "google_compute_instance" "abm-w1" {
  name         = "abm-w1"
  machine_type = "n1-standard-8"
  zone         = "us-central1-a"
  can_ip_forward = true
  min_cpu_platform = "Intel Haswell"

  boot_disk {
    initialize_params {
      image = "ubuntu-2004-lts"
      size = "200"
      type = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vpc_subnet_1.id

    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    project = "anthos"
  }
  metadata_startup_script = file("${path.module}/startup.sh")
}

# Create Worker Node 2
resource "google_compute_instance" "abm-w2" {
  name         = "abm-w2"
  machine_type = "n1-standard-8"
  zone         = "us-central1-a"
  can_ip_forward = true
  min_cpu_platform = "Intel Haswell"

  boot_disk {
    initialize_params {
      image = "ubuntu-2004-lts"
      size = "200"
      type = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.vpc_subnet_1.id

    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    project = "anthos"
  }
  metadata_startup_script = file("${path.module}/startup.sh")
}
