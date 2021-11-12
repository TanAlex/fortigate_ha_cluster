### GCP terraform for HA setup
terraform {
  required_version = ">=0.12.0"
  required_providers {
    google      = "2.11.0"
    google-beta = "2.13"
  }
}
provider "google" {
  #credentials = file("${var.account}")
  project     = var.project
  region      = "us-central1"
  zone        = "us-central1-c"

}
provider "google-beta" {
  #credentials = file("${var.account}")
  project     = var.project
  region      = var.region
  zone        = var.zone
}

# Randomize string to avoid duplication
resource "random_string" "random_name_post" {
  length           = 3
  special          = true
  override_special = ""
  min_lower        = 3
}

# Create log disk for active
resource "google_compute_disk" "logdisk" {
  name = "log-disk-${random_string.random_name_post.result}"
  size = 30
  type = "pd-standard"
  zone = var.zone
}

# Create log disk for passive
resource "google_compute_disk" "logdisk2" {
  name = "log-disk2-${random_string.random_name_post.result}"
  size = 30
  type = "pd-standard"
  zone = var.zone
}

########### Network Related
### VPC ###
resource "google_compute_network" "vpc_network" {
  name                    = "vpc-${random_string.random_name_post.result}"
  auto_create_subnetworks = false
}

resource "google_compute_network" "vpc_network2" {
  name                    = "vpc2-${random_string.random_name_post.result}"
  auto_create_subnetworks = false
}

resource "google_compute_network" "vpc_network3" {
  name                    = "vpc3-${random_string.random_name_post.result}"
  auto_create_subnetworks = false
}

resource "google_compute_network" "vpc_network4" {
  name                    = "vpc4-${random_string.random_name_post.result}"
  auto_create_subnetworks = false
}



### Public Subnet ###
resource "google_compute_subnetwork" "public_subnet" {
  name                     = "public-subnet-${random_string.random_name_post.result}"
  region                   = var.region
  network                  = google_compute_network.vpc_network.name
  ip_cidr_range            = var.public_subnet
  private_ip_google_access = true
}
### Private Subnet ###
resource "google_compute_subnetwork" "private_subnet" {
  name          = "private-subnet-${random_string.random_name_post.result}"
  region        = var.region
  network       = google_compute_network.vpc_network2.name
  ip_cidr_range = var.protected_subnet
}
### HA Sync Subnet ###
resource "google_compute_subnetwork" "ha_subnet" {
  name          = "sync-subnet-${random_string.random_name_post.result}"
  region        = var.region
  network       = google_compute_network.vpc_network3.name
  ip_cidr_range = var.ha_subnet
}
### HA MGMT Subnet ###
resource "google_compute_subnetwork" "mgmt_subnet" {
  name          = "mgmt-subnet-${random_string.random_name_post.result}"
  region        = var.region
  network       = google_compute_network.vpc_network4.name
  ip_cidr_range = var.mgmt_subnet
}


resource "google_compute_route" "internal1" {
  name        = "internal-route1-${random_string.random_name_post.result}"
  dest_range  = "172.16.0.0/16"
  network     = google_compute_network.vpc_network2.name
  next_hop_ip = var.active_port2_ip
  priority    = 100
  depends_on  = [google_compute_subnetwork.private_subnet]
}

resource "google_compute_route" "internal0" {
  name        = "internal-route0-${random_string.random_name_post.result}"
  dest_range  = "172.16.0.0/16"
  network     = google_compute_network.vpc_network.name
  next_hop_ip = var.active_port1_ip
  priority    = 100
  depends_on  = [google_compute_subnetwork.private_subnet]
}

# Firewall Rule External
resource "google_compute_firewall" "allow-fgt" {
  name    = "allow-fgt-${random_string.random_name_post.result}"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22", "80", "443"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["0.0.0.0/0"]
  #target_tags   = ["allow-fgt"]
}

# Firewall Rule Internal
resource "google_compute_firewall" "allow-internal" {
  name    = "allow-internal-${random_string.random_name_post.result}"
  network = google_compute_network.vpc_network2.name

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  #target_tags   = ["allow-internal"]
}

# Firewall Rule HA SYNC
resource "google_compute_firewall" "allow-sync" {
  name    = "allow-sync-${random_string.random_name_post.result}"
  network = google_compute_network.vpc_network3.name

  allow {
    protocol = "all"
  }

  source_ranges = ["0.0.0.0/0"]
  # target_tags   = ["allow-sync"]
}

# Firewall Rule HA MGMT
resource "google_compute_firewall" "allow-mgmt" {
  name    = "allow-mgmt-${random_string.random_name_post.result}"
  network = google_compute_network.vpc_network4.name

  allow {
    protocol = "all"
  }
  source_ranges = ["0.0.0.0/0"]
  # target_tags   = ["allow-mgmt"]
}

########### Instance Related

# active userdata pre-configuration
data "template_file" "setup-active" {
  template = "${file("${path.module}/active")}"
  vars = {
    active_port1_ip   = var.active_port1_ip
    active_port1_mask = var.active_port1_mask
    active_port2_ip   = var.active_port2_ip
    active_port2_mask = var.active_port2_mask
    active_port3_ip   = var.active_port3_ip
    active_port3_mask = var.active_port3_mask
    active_port4_ip   = var.active_port4_ip
    active_port4_mask = var.active_port4_mask
    hamgmt_gateway_ip = var.mgmt_gateway     //  hamgmt gateway ip
    passive_hb_ip     = var.passive_port3_ip // passive hb ip
    hb_netmask        = var.mgmt_mask        // mgmt netmask
    port1_gateway     = google_compute_subnetwork.public_subnet.gateway_address
    clusterip         = "cluster-ip-${random_string.random_name_post.result}"
    internalroute1     = "internal-route1-${random_string.random_name_post.result}"
    internalroute0     = "internal-route0-${random_string.random_name_post.result}"
  }
}

# passive userdata pre-configuration
data "template_file" "setup-passive" {
  template = "${file("${path.module}/passive")}"
  vars = {
    passive_port1_ip   = var.passive_port1_ip
    passive_port1_mask = var.passive_port1_mask
    passive_port2_ip   = var.passive_port2_ip
    passive_port2_mask = var.passive_port2_mask
    passive_port3_ip   = var.passive_port3_ip
    passive_port3_mask = var.passive_port3_mask
    passive_port4_ip   = var.passive_port4_ip
    passive_port4_mask = var.passive_port4_mask
    hamgmt_gateway_ip  = var.mgmt_gateway    //  hamgmt gateway ip
    active_hb_ip       = var.active_port3_ip // active hb ip
    hb_netmask         = var.mgmt_mask       // mgmt netmask
    port1_gateway      = google_compute_subnetwork.public_subnet.gateway_address
    clusterip          = "cluster-ip-${random_string.random_name_post.result}"
    internalroute1     = "internal-route1-${random_string.random_name_post.result}"
    internalroute0     = "internal-route0-${random_string.random_name_post.result}"
  }
}

# Create static Private IPs

resource "google_compute_address" "active-port1-ip" {
  name         = "active-port1-ip"
  subnetwork   = google_compute_subnetwork.public_subnet.name
  address_type = "INTERNAL"
  address      = var.active_port1_ip
  region       = var.region
}

resource "google_compute_address" "active-port2-ip" {
  name         = "active-port2-ip"
  subnetwork   = google_compute_subnetwork.private_subnet.name
  address_type = "INTERNAL"
  address      = var.active_port2_ip
  region       = var.region
}
resource "google_compute_address" "active-port3-ip" {
  name         = "active-port3-ip"
  subnetwork   = google_compute_subnetwork.ha_subnet.name
  address_type = "INTERNAL"
  address      = var.active_port3_ip
  region       = var.region
}
resource "google_compute_address" "active-port4-ip" {
  name         = "active-port4-ip"
  subnetwork   = google_compute_subnetwork.mgmt_subnet.name
  address_type = "INTERNAL"
  address      = var.active_port4_ip
  region       = var.region
}

# Create static passive VM private IPs
resource "google_compute_address" "passive-port1-ip" {
  name         = "passive-port1-ip"
  subnetwork   = google_compute_subnetwork.public_subnet.name
  address_type = "INTERNAL"
  address      = var.passive_port1_ip
  region       = var.region
}

resource "google_compute_address" "passive-port2-ip" {
  name         = "passive-port2-ip"
  subnetwork   = google_compute_subnetwork.private_subnet.name
  address_type = "INTERNAL"
  address      = var.passive_port2_ip
  region       = var.region
}
resource "google_compute_address" "passive-port3-ip" {
  name         = "passive-port3-ip"
  subnetwork   = google_compute_subnetwork.ha_subnet.name
  address_type = "INTERNAL"
  address      = var.passive_port3_ip
  region       = var.region
}
resource "google_compute_address" "passive-port4-ip" {
  name         = "passive-port4-ip"
  subnetwork   = google_compute_subnetwork.mgmt_subnet.name
  address_type = "INTERNAL"
  address      = var.passive_port4_ip
  region       = var.region
}

# Create static cluster ip
resource "google_compute_address" "static" {
  name = "cluster-ip-${random_string.random_name_post.result}"
  region = var.region
}

# Create FGTVM compute active instance
resource "google_compute_instance" "default" {
  name           = "fgt-1-${random_string.random_name_post.result}"
  machine_type   = var.machine
  zone           = var.zone
  can_ip_forward = "true"

  tags = ["allow-fgt", "allow-internal", "allow-sync", "allow-mgmt"]

  boot_disk {
    initialize_params {
      image = var.image
    }
  }
  attached_disk {
    source = google_compute_disk.logdisk.name
  }
  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.name
    network_ip = google_compute_address.active-port1-ip.address
    access_config {
      nat_ip = google_compute_address.static.address
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.name
    network_ip = google_compute_address.active-port2-ip.address
  }

  network_interface {
    subnetwork = google_compute_subnetwork.ha_subnet.name
    network_ip = google_compute_address.active-port3-ip.address
  }

  network_interface {
    subnetwork = google_compute_subnetwork.mgmt_subnet.name
    network_ip = google_compute_address.active-port4-ip.address
    access_config {
    }
  }

  metadata = {
    user-data = "${data.template_file.setup-active.rendered}"
    license = fileexists("${path.module}/${var.licenseFile}") ? "${file(var.licenseFile)}" : null
  }
  service_account {
    scopes = ["userinfo-email", "compute-rw", "storage-ro", "cloud-platform"]
  }
  scheduling {
    preemptible       = true
    automatic_restart = false
  }
}

# Create FGTVM compute passive instance
resource "google_compute_instance" "default2" {
  name           = "fgt-2-${random_string.random_name_post.result}"
  machine_type   = var.machine
  zone           = var.zone
  can_ip_forward = "true"

  tags = ["allow-fgt", "allow-internal", "allow-sync", "allow-mgmt"]

  boot_disk {
    initialize_params {
      image = var.image
    }
  }
  attached_disk {
    source = google_compute_disk.logdisk2.name
  }
  network_interface {
    subnetwork = google_compute_subnetwork.public_subnet.name
    network_ip = google_compute_address.passive-port1-ip.address
  }
  network_interface {
    subnetwork = google_compute_subnetwork.private_subnet.name
    network_ip = google_compute_address.passive-port2-ip.address
  }
  network_interface {
    subnetwork = google_compute_subnetwork.ha_subnet.name
    network_ip = google_compute_address.passive-port3-ip.address
  }
  network_interface {
    subnetwork = google_compute_subnetwork.mgmt_subnet.name
    network_ip = google_compute_address.passive-port4-ip.address
    access_config {
    }
  }
  metadata = {
    user-data = "${data.template_file.setup-passive.rendered}"
    license = fileexists("${path.module}/${var.licenseFile2}") ? "${file(var.licenseFile2)}" : null
  }
  service_account {
    scopes = ["userinfo-email", "compute-rw", "storage-ro", "cloud-platform"]
  }
  scheduling {
    preemptible       = true
    automatic_restart = false
  }
}





# Output
output "FortiGate-HA-Cluster-IP" {
  value = "${google_compute_instance.default.network_interface.0.access_config.*.nat_ip}"
}
# output "FortiGate-HA-Master-MGMT-IP" {
#   value = "${google_compute_instance.default.network_interface.3.access_config.0.nat_ip}"
# }
# output "FortiGate-HA-Slave-MGMT-IP" {
#   value = "${google_compute_instance.default2.network_interface.3.access_config.0.nat_ip}"
# }

output "FortiGate-Username" {
  value = "admin"
}
output "FortiGate-Password" {
  value = google_compute_instance.default.instance_id
}