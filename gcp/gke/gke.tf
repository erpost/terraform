provider "google" {
  project = var.project
  region  = var.region
}

# Create VPC
resource "google_compute_network" "vpc_network" {
  name                    = "vpc-gke"
  auto_create_subnetworks = false
}

# Create Subnetwork 1
resource "google_compute_subnetwork" "vpc_subnet_1" {
  name          = "subnet-gke1"
  ip_cidr_range = "10.1.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.id
}

# Create Subnetwork 2
resource "google_compute_subnetwork" "vpc_subnet_2" {
  name          = "subnet-gke2"
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

# Create GKE Cluster
resource "google_container_cluster" "cluster-gke1" {
  name     = "cluster-gke1"
  location = "us-central1-a"
  remove_default_node_pool = true
  initial_node_count       = 1
  workload_identity_config {
    identity_namespace = "${var.project}.svc.id.goog"
  }

  network    = google_compute_network.vpc_network.name
  subnetwork = google_compute_subnetwork.vpc_subnet_1.name
}

resource "google_container_node_pool" "node-pool-gke1" {
  name       = "node-pool-gke1"
  location   = "us-central1-a"
  cluster    = google_container_cluster.cluster-gke1.name
  node_count = 2

  node_config {
    preemptible  = false
    machine_type = "e2-medium"
  }
}