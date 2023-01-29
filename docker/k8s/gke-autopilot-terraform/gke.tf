variable "gke_username" {
  default     = ""
  description = "gke username"
}

variable "gke_password" {
  default     = ""
  description = "gke password"
}

# GKE cluster
resource "google_container_cluster" "primary" {
  name     = "${var.project_id}-gke"
  location = var.region

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name

  # workaround for:
  # Max pods constraint on node pools for Autopilot clusters should be 32
  ip_allocation_policy {
  }
  node_config {
    spot = true
  }
  # Enabling Autopilot for this cluster
  enable_autopilot = true
}