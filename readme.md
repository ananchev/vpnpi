# Raspberry Pi 5 VPN Gateway

## Objective

Configure a **Raspberry Pi 5** running **Ubuntu Server** to act as a **VPN gateway**, routing Ethernet-connected client traffic over an **OpenVPN tunnel** established via a USB Wi-Fi adapter.

The device also supports **remote administration** (via SSH and XRDP) through a **reverse SSH tunnel** when an LTE dongle or Wi-Fi is available. The entire setup is reproducible via **Ansible**.

---

## Platform

- **Device:** Raspberry Pi 5
- **OS:** Ubuntu Server 24.04.2 LTS (64-bit)
- **Desktop Environment:** XFCE
- **Remote Desktop Access:** XRDP
- **Automation:** Fully provisioned via Ansible

---

## Network Interfaces

| Interface        | Purpose                           | Device                            | Notes                                |
|------------------|-----------------------------------|-----------------------------------|--------------------------------------|
| `wlan1`          | Primary internet uplink           | TP-Link Archer T3U Plus (USB Wi-Fi) | Used for OpenVPN connection         |
| `eth0`           | Downstream client connection      | RJ45 Ethernet                     | Routed through VPN tunnel; also used for local admin access |
| `wlan0`          | Dual-mode Wi-Fi interface         | Built-in Wi-Fi                    | **Client mode**: Connect to home Wi-Fi (default)<br/>**AP mode**: Wi-Fi access point for VPN clients |
| `wwan0` | Remote access uplink (when present) | USB LTE Modem                     | Triggers reverse SSH tunnel, no VPN usage |

---

## Reverse SSH Tunnel (Admin Access)

- Triggered when **LTE modem is plugged in** _or_ **wlan1 is connected**
- Uses `autossh` to maintain a persistent tunnel
- Tunnel forwards:
  - **SSH:** `localhost:22` → `remote-server:22221`
  - **XRDP:** `localhost:3389` → `remote-server:33891`
- Admin can access:
  - `ssh -p 22221 user@remote-server`
  - RDP to `remote-server:33891`

---

## Configuration

### VPN Gateway
- Connect to internet via `wlan1` (USB Wi-Fi)
- Establish OpenVPN connection automatically on boot
- All downstream (`eth0`) traffic must go through VPN
- VPN kill-switch enabled (no fallback to local internet)

### Remote Admin via Reverse SSH
- On LTE or `wlan1` connection, automatically open reverse SSH tunnel
- Tunnel exposes both `ssh` and `xrdp` access ports
- The SSH tunnel binds forwarded ports externally to allow connections from any host
- LTE **not used** for VPN — only for management

### XFCE GUI & XRDP
- Install **XFCE** desktop environment
- Enable **XRDP** for remote GUI login
- System boots to **console** (no local display manager)
- GUI accessed **only remotely** (via XRDP or manually via `startxfce4`)

### Built-in Wi-Fi (`wlan0`) - Dual Mode
- **Client mode (default):** Connects to home Wi-Fi for provisioning and maintenance
- **Access Point mode (optional):** Acts as Wi-Fi access point for VPN clients
- Toggle between modes using provided scripts:
  - `sudo wifi-toggle-ap.sh` - Switch to access point mode
  - `sudo wifi-toggle-client.sh` - Switch back to client mode
- **AP Details:**
  - SSID: `VPNPI-Gateway`
  - Password: `VPNPiAccess2024`
  - Client subnet: `192.168.51.0/24`
  - All AP clients routed through VPN tunnel

### LAN Access via `eth0`
- While `eth0` is normally used for VPN client traffic, it also supports:
  - **Direct SSH and XRDP access from the connected client**
  - Useful for **captive portal login** and **offline troubleshooting**
- Requires:
  - Static or predictable IP for `eth0`
  - Firewall allowing access from local subnet
  - VPN NAT rules to preserve admin access during tunnel startup

---

## Ansible-Based Configuration

- Starting point: Ubuntu Server image with:
  - SSH enabled
  - Preconfigured Wi-Fi for `wlan0` (home)
- Configuration is fully automated via Ansible
- Ansible roles:

```yaml
roles:
  - base-system
  - network-config
  - wifi-upstream
  - vpn-gateway
  - reverse-ssh
  - gui-desktop
  - wifi-mode-toggle
```

---

## Wi-Fi Mode Toggle Workflow

The system supports two modes for the `wlan0` interface:

### 1. Initial Deployment (Client Mode)
```bash
# Deploy all roles via home Wi-Fi connection
ansible-playbook -i vpnpi deploy.yml
```

### 2. Switch to Access Point Mode
```bash
# Connect via alternative method (reverse SSH, eth0, or console)
ssh -p 22221 user@remote-server
# OR
ssh user@192.168.50.1

# Switch wlan0 to AP mode
sudo wifi-toggle-ap.sh
```

### 3. Return to Client Mode (for maintenance)
```bash
# Switch back to client mode
sudo wifi-toggle-client.sh
```

### 4. Check Current Mode
```bash
# View current mode and status
wifi-mode-status.sh
```

### Mode Persistence
- **Selected mode persists across reboots**
- **Services auto-start** based on last active mode
- **iptables rules** are automatically restored
- **Network configuration** is persistent

### AP Mode Details
- **SSID:** `VPNPI-Gateway`
- **Password:** `VPNPiAccess2024`  
- **AP IP:** `192.168.51.1`
- **Client DHCP Range:** `192.168.51.10-192.168.51.100`
- **Client Traffic:** All routed through VPN tunnel (`tun0`)
- **Kill-Switch:** Enabled (no fallback to local internet)

---

## Roles Descriptions

### `base-system`
Installs basic system utilities, enables SSH, sets locale/timezone, and configures APT and system updates.

### `network-config`
Sets up static IP or DHCP settings for `eth0` and `wlan0`, and configures hostnames, DNS, and optional firewall rules.

### `wifi-upstream`
Installs and configures support for the Archer T3U Plus (Realtek-based USB Wi-Fi), assigns it as `wlan1`, and manages network profiles for uplink use.

### `vpn-gateway`
Installs and configures **OpenVPN**, enables NAT, applies routing rules, and enforces a kill-switch to ensure `eth0` traffic only exits through the VPN.

### `reverse-ssh`
Installs and configures **autossh** to maintain a reverse SSH tunnel (triggered by LTE or `wlan1` connection) to a remote server, exposing SSH and XRDP ports.

### `gui-desktop`
Installs **XFCE** desktop, configures **XRDP**, disables auto-login to GUI, and sets up XRDP-specific session behavior.

### `wifi-mode-toggle`
Deploys toggle scripts to switch `wlan0` between **client mode** (connects to home Wi-Fi) and **access point mode** (provides Wi-Fi access for VPN clients). Includes hostapd, DHCP, and VPN routing configuration for AP mode.

---
