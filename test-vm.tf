resource "google_compute_instance" "test-vm1" {
  name = "test-vm-1"
  machine_type = "n2-standard-2"
  zone = var.zone
  project = var.project
  tags = ["test-vm"]

  // Specify the Operating System Family and version.
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }


  // Define a network interface in the correct subnet.
  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.name
    // Add an ephemeral external IP.
    access_config {
      // Ephemeral IP
    }
  }

  // Allow the instance to be stopped by terraform when updating configuration
  allow_stopping_for_update = true

}

resource "google_compute_instance" "test-vm2" {
  name = "test-vm-2"
  machine_type = "n2-standard-2"
  zone = var.zone
  project = var.project
  tags = ["test-vm"]

  // Specify the Operating System Family and version.
  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
    }
  }


  // Define a network interface in the correct subnet.
  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.name
    // Add an ephemeral external IP.
    access_config {
      // Ephemeral IP
    }
  }

  // Allow the instance to be stopped by terraform when updating configuration
  allow_stopping_for_update = true

}