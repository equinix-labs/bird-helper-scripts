# Helper Scripts for configuring BIRD on Equinix Metal

This little repo contains some helper scripts for configuring the BIRD Internet Routing Daemon on your Equinix Metal devices. Since BIRD and BIRD2 have different config file formats, you'll need to specify which one you need. Written as a companion for the guides [Configuring BGP with BIRD 1.6 on an Equinix Metal Server](https://deploy.equinix.com/developers/guides/configuring-bgp-with-bird/) and [Configuring BGP with BIRD 2 on Equinix Metal](https://deploy.equinix.com/developers/guides/configuring-bgp-with-bird2.0/)

## Prerequisites

You will need either `bird` or `bird2` installed on your system before running the script with the corresponding name. 

`jq` is required for parsing metadata from the metadata service.

These scripts do not install either, but do check and abort if not present to avoid half-configuring systems and causing problems. If using these in automation pipelines, it's recommended to ensure package presence through some other means like `cloud-init`. 

## Running the Scripts

Either script is intended to automate the configuration of your system to advertise an Elastic IP using BGP. To execute, simply run the script passing the Elastic IP through the input. Ex:

```bash
./bird2-setup.sh 192.0.2.1
```

This would configure your server to advertise the address `192.0.2.1` to it's neighbors on Equinix Metal using BIRD 2.

## Use in Automation

These can be used in tandem with platforms like Terraform to automatically setup systems and advertise a global IP address for use in anycast applications. An example of this type of setup can be seen in the [anycast-demo](https://github.com/equinix-labs/anycast_demo) repository. 

One could also reference these through the `User Data` when creating a new Metal device using `cloud-init`. An example `cloud-config` for each version of bird has been included. To try this out, copy and paste the appropriate `cloud-config` into the `User Data` field in equinix metal when provisioning a new device. Upon provisioning, the system should automatically configure the appropriate BIRD daemon and begin synchronizing with peers within a few minutes.