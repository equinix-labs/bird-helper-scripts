#! /bin/bash

bird=$(dpkg-query -W -f='${Status}' bird2 2>/dev/null | grep -c "ok installed")
jq=$(dpkg-query -W -f='${Status}' jq 2>/dev/null | grep -c "ok installed")

if [ $bird -eq 0 ] || [ $jq -eq 0 ]; then
  echo "missing required packages. Please ensure bird2 and jq are installed and try again."
  exit 1
fi

# Timer to wait for bgp activation on newly setup systems. cloud-init will sometimes run
# before this is done, the timer waits for bgp neighbors to exist before continuing.
echo "$(date)" >> /root/timer
until [ $(curl -s https://metadata.platformequinix.com/metadata | jq -r '.bgp_neighbors[0].peer_ips[0]') != 'null' ]; do
  echo "$(date)" >> /root/timer
  sleep 10
done

# Query metadata service to retrieve peer information
json=$(curl -s https://metadata.platformequinix.com/metadata)
MY_PRIVATE_IP=$(echo $json | jq -r ".network.addresses[] | select(.public == false) | .address")
MY_PRIVATE_GW=$(echo $json | jq -r '.network.addresses[] | select(.public == false and .address_family == 4).gateway')
MY_PEER_1=$(echo $json | jq -r '.bgp_neighbors[0].peer_ips[0]')
MY_PEER_2=$(echo $json | jq -r '.bgp_neighbors[0].peer_ips[1]')
MY_ASN=$(echo $json | jq -r '.bgp_neighbors[0].peer_as')

# Use input as elastic IP
ELASTIC_IP=$1

# Setup loopback interface with advertised IP if it does not already exist
if grep --quiet 'lo:0' /etc/network/interfaces; then
  echo "lo:0 config already exists"
else
echo "
auto lo:0
  iface lo:0 inet static
  address $ELASTIC_IP
  netmask 255.255.255.255" >> /etc/network/interfaces
fi

# Generate the config file
cat << EOF > /etc/bird/bird.conf
# Create a filter to advertise only the Elastic IP we've chosen.
# This IP must be bound to the lo interface
filter equinix_bgp {
  if net = $ELASTIC_IP/32 then accept;
}

router id $MY_PRIVATE_IP;

# Add direct routes only on ipv4 on the lo interface
protocol direct {
  ipv4;
  interface "lo";
}

# Import routes from kernel
protocol kernel {
  scan time 20;
  ipv4 {
    import all;
    export all;
  };
}

# Static routes to reach peers via private Equinix network
# Peers always 169.254.255.1 & 169.254.255.2 on Equinix Metal
protocol static {
  ipv4;
  route $MY_PEER_1/32 via $MY_PRIVATE_GW;
  route $MY_PEER_2/32 via $MY_PRIVATE_GW;
}

# Check for interface up/down events
protocol device {
  scan time 10; # Scan interfaces every 10 seconds
}

# BGP advertisement to neighbors
# Neighbor ASN should always be 65530 on Equinix Metal
# edit password line and uncomment as needed
protocol bgp neighbor_v4_1 {
  local as 65000;
  neighbor $MY_PEER_1 as $MY_ASN;
  #password string;
  multihop 5;
  ipv4 {
    export filter equinix_bgp;
    import all;
  };
}

protocol bgp neighbor_v4_2 {
  local as 65000;
  multihop 5;
  neighbor $MY_PEER_2 as $MY_ASN;
  #password string;
  ipv4 {
    export filter equinix_bgp;
    import all;
  };
}
EOF

# ensure the interface is up and restart service with new config
ifup lo:0
service bird restart
