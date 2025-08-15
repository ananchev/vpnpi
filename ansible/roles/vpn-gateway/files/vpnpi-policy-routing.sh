#!/bin/bash
# vpnpi-policy-routing.sh: Ensure policy routing for LAN clients via VPN tunnel

# Wait for tun0 to exist (max 10 seconds)
for i in {1..10}; do
  ip link show tun0 >/dev/null 2>&1 && break
  sleep 1
  if [ $i -eq 10 ]; then
    echo "tun0 not found after 10 seconds, exiting." >&2
    exit 1
  fi
done

# Add custom routing table if not present
grep -q '^200 vpnclients' /etc/iproute2/rt_tables || echo '200 vpnclients' >> /etc/iproute2/rt_tables

# Remove any existing rules for the LAN subnet
table_id=200
ip rule del from 192.168.50.0/24 table $table_id 2>/dev/null

# Add policy rule and default route for vpnclients table
ip rule add from 192.168.50.0/24 table vpnclients
ip route replace default dev tun0 table vpnclients
