# README

This repo is for a PoC NVA (Network Virtual Appliance) solution in GCP

Reference:
https://docs.fortinet.com/document/fortigate/6.0.0/cookbook/509515/configuring-the-primary-fortigate-for-ha
https://github.com/fortinet/fortigate-terraform-deploy/blob/master/gcp/6.4/single/main.tf

## Main issues and how to fix them

* Not able to ping any Interfaces from test VMs  
  When fortigate is in HA cluster mode, all the insterfaces on the 'standby' VM are no longer pingable.  
  In the terraform code in their original solution above, they don't use 'google_compute_address' to reserve static IPs for private IPs.  
  They simply just directly assign IPs to the VM's interfaces. That is the root cause of the problem.

  **Solution:**
  Use 'google_compute_address' for all the 8 private IPs and use 'dhcp' mode rather than 'static' for interface 1 and 2

* Static routes missing for vpc1 and vpc2 and new static route won't update 'next hop target' IP when cluster fails-over  
  
  **Solution:**
  Comment out the default static route and add the missing route for VPC1 and add it under sdn-connector so Fortigate can manage it when it does failover.  
```
#config router static
#    edit 1
#       set device port1
#       set gateway ${port1_gateway}
#    next
#end
config system sdn-connector
    edit "gcp"
        set type gcp
        set ha-status enable
        config external-ip
            edit ${clusterip}
            next
        end
        config route
            edit ${internalroute1}
            next
            edit ${internalroute0}
            next
        end
    next
end
```

## Test the solution

Workflow:

* Clone this repo and update terraform.tfvars to modify the `project` to your project id
* Run `terraform init` `plan` and `apply` to deploy it
* Terraform will show output like these
```
FortiGate-HA-Cluster-IP = tolist([
  "35.203.20.65",
])
FortiGate-Password = "2997643659759042515"
FortiGate-Username = "admin"
```
The password is just the new appliance VM's `Instance ID`, use the public IP and user admin to login

The code will also start 2 test VMs, they will be used to test routes and connections