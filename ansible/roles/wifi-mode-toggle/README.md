# Wi-Fi Mode Toggle Role

## Overview

This Ansible role enables the `wlan0` interface on the VPN Pi to operate in two distinct modes:

- **Client Mode (Default)**: `wlan0` connects to home Wi-Fi network for provisioning and maintenance
- **Access Point Mode**: `wlan0` acts as a Wi-Fi access point, providing VPN access to wireless clients

The role deploys the necessary configurations and scripts but leaves the system in **client mode** by default.

## Components Deployed

### Configuration Files
- **`/etc/hostapd/hostapd-wlan0.conf`**: Access point configuration
  - SSID: `VPNPI-Gateway`
  - WPA2 security with password `VPNPiAccess2024`
  - Channel 7, 2.4GHz
  
- **`/etc/dnsmasq.d/wlan0-ap.conf`**: DHCP server for AP clients
  - IP range: `192.168.51.10-192.168.51.100`
  - Gateway: `192.168.51.1`
  - DNS: `8.8.8.8, 1.1.1.1`

### Systemd Services
- **`hostapd-wlan0.service`**: Manages the access point daemon
- **`dnsmasq-wlan0.service`**: Manages DHCP for AP clients  
- **`wifi-mode-restore.service`**: Restores selected mode on boot

### Scripts

#### `/usr/local/bin/wifi-toggle-ap.sh`
**Purpose**: Switch `wlan0` from client mode to access point mode

**What it does**:
1. **Safety check**: Verifies VPN tunnel (`tun0`) is active
2. **Disconnect client**: Stops any existing Wi-Fi client connections
3. **Disable NetworkManager**: Prevents conflicts with hostapd
4. **Configure networking**: Adds static IP and VPN routing rules
5. **Start services**: Enables and starts hostapd + dnsmasq services
6. **Verify operation**: Checks services are running correctly
7. **Persist state**: Records AP mode in state file

**Key features**:
- Interactive confirmation if VPN is down
- Automatic rollback if services fail to start
- Persistent across reboots (services enabled)

#### `/usr/local/bin/wifi-toggle-client.sh`
**Purpose**: Switch `wlan0` from access point mode back to client mode

**What it does**:
1. **Stop AP services**: Disables and stops hostapd + dnsmasq
2. **Remove VPN routing**: Cleans up iptables rules and static IP
3. **Re-enable NetworkManager**: Allows normal Wi-Fi client operation
4. **Reconnect**: Attempts to connect to known Wi-Fi networks
5. **Verify connection**: Reports connection status
6. **Persist state**: Records client mode in state file

**Key features**:
- Graceful service shutdown
- Automatic cleanup of networking configuration
- Attempts reconnection to home Wi-Fi
- Persistent across reboots (services disabled)

#### `/usr/local/bin/update-vpn-routing.sh`
**Purpose**: Manage VPN routing and firewall rules for `wlan0` subnet

**Operations**:
- **`add-wlan0`**: Add `192.168.51.0/24` to VPN routing
  - Static IP configuration for `wlan0`
  - Policy routing rules for AP clients
  - NAT masquerade rules for VPN traffic
  - Kill-switch rules (block non-VPN traffic)
  - Persistent iptables and network config
  
- **`remove-wlan0`**: Remove `wlan0` from VPN routing
  - Clean up all routing rules
  - Remove static IP and network config
  - Save cleaned iptables state

#### `/usr/local/bin/wifi-mode-restore.sh`
**Purpose**: Restore the selected Wi-Fi mode on system boot

**How it works**:
1. **Read state file**: `/var/lib/wifi-mode-toggle/current-mode`
2. **Wait for network**: Ensures interfaces are ready
3. **Restore mode**: 
   - If `ap`: runs `wifi-toggle-ap.sh`
   - If `client`: does nothing (default state)
4. **Error handling**: Defaults to client mode if state unclear

#### `/usr/local/bin/wifi-mode-status.sh`
**Purpose**: Display current Wi-Fi mode and system status

**Information shown**:
- Mode history with timestamps
- Current active mode (Client/AP/Unknown)
- Service status (hostapd, dnsmasq)
- Network connection details
- Available commands

## State Management

### State Tracking
- **File**: `/var/lib/wifi-mode-toggle/current-mode`
- **Format**: 
  ```
  2024-08-16T10:30:45Z: AP mode enabled
  ap
  ```
- **Purpose**: Persistent record of active mode and history

### Persistence Mechanisms

| Component | How It Persists |
|-----------|----------------|
| **Service State** | `systemctl enable/disable` |
| **iptables Rules** | Saved to `/etc/iptables/rules.v4` |
| **Static IP** | systemd-networkd config file |
| **Mode State** | State file + restoration service |
| **NetworkManager** | Managed/unmanaged state |

### Boot Sequence
1. **Standard services start** (NetworkManager, systemd-networkd)
2. **iptables rules restored** (via iptables-persistent)
3. **wifi-mode-restore.service runs** (after network online)
4. **Mode-specific services start** (hostapd/dnsmasq if AP mode)
5. **Network configuration applied** (static IP if AP mode)

## Usage

### Initial Deployment
```bash
# Deploy via home Wi-Fi (client mode maintained)
ansible-playbook -i vpnpi deploy.yml

# System remains in client mode - safe for Ansible connectivity
```

### Switch to AP Mode  
```bash
# Connect via alternative method (reverse SSH, eth0, console)
ssh -p 22221 user@remote-server

# Switch to AP mode (persistent)
sudo wifi-toggle-ap.sh

# Verify
wifi-mode-status.sh
```

### Return to Client Mode
```bash
# Switch back (persistent)
sudo wifi-toggle-client.sh

# Reconnects to home Wi-Fi automatically
```

### After Reboot
- **AP mode**: Automatically restored, services start, clients can connect
- **Client mode**: Normal home Wi-Fi connection, AP services remain disabled

## Troubleshooting

### Check Current Status
```bash
wifi-mode-status.sh
```

### View Service Logs  
```bash
journalctl -u hostapd-wlan0 -f
journalctl -u dnsmasq-wlan0 -f
journalctl -u wifi-mode-restore -f
```

### Manual Service Control
```bash
# AP Services
systemctl status hostapd-wlan0 dnsmasq-wlan0

# Check iptables rules
iptables -L -n -v
iptables -t nat -L -n -v

# Check routing
ip route show table vpnclients
ip rule show
```

## Files Created

```
/etc/hostapd/hostapd-wlan0.conf
/etc/dnsmasq.d/wlan0-ap.conf
/etc/systemd/system/hostapd-wlan0.service
/etc/systemd/system/dnsmasq-wlan0.service  
/etc/systemd/system/wifi-mode-restore.service
/usr/local/bin/wifi-toggle-ap.sh
/usr/local/bin/wifi-toggle-client.sh
/usr/local/bin/update-vpn-routing.sh
/usr/local/bin/wifi-mode-restore.sh
/usr/local/bin/wifi-mode-status.sh
/usr/local/bin/README-wifi-toggle.md
/var/lib/wifi-mode-toggle/current-mode
/etc/systemd/network/15-wlan0-ap.network (when in AP mode)
```
