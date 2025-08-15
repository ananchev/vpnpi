# VPNPI Troubleshooting Guide

## Project Overview
- **Device:** Raspberry Pi 5, Ubuntu Server
- **Automation:** Ansible roles/playbooks
- **Key Features:**
  - All LAN (`eth0`) traffic routed through OpenVPN tunnel (`tun0`) over `wlan1` (USB Wi-Fi)
  - Admin/SSH access via `wlan0`
  - DHCP on `eth0` (dnsmasq)
  - GUI/XRDP for remote admin
  - Wi-Fi and LTE interfaces managed by NetworkManager
  - Policy routing and VPN kill-switch
  - Reverse SSH tunnel using LTE (`wwan0`) or fallback to `wlan1` (never VPN)

---

## Interface Naming & udev
- **wlan1:** Renamed by MAC address (Archer T3U Plus)
- **wwan0:** Renamed by vendor/product ID (Huawei LTE dongle)
- **Check interface names:**
  ```sh
  ip a
  nmcli device status
  ```
- **If interface is missing or misnamed:**
  - Check udev rules in `/etc/udev/rules.d/`
  - Reload/trigger udev: `udevadm control --reload && udevadm trigger`
  - Reboot if needed

---

## NetworkManager & Netplan
- **NetworkManager** manages all Wi-Fi and LTE interfaces
- **Netplan** configures only `wlan0`/`wlan1` (not LTE)
- **Check status:**
  ```sh
  systemctl status NetworkManager
  nmcli device status
  nmcli connection show
  ```

---

## OpenVPN & Policy Routing
- **OpenVPN** runs as a client, config in `/etc/openvpn/client/`
- **Policy routing** script is triggered by OpenVPN `up` script
- **Check VPN status:**
  ```sh
  systemctl status openvpn-client@vpnpi
  ip route show table vpnclients
  ip rule
  iptables -t nat -L -n -v
  iptables -L -n -v
  ```
- **If LAN clients can't reach the internet:**
  - Check if `tun0` is up
  - Check NAT/masquerade rules
  - Check policy routing script logs/output
  - Check kill-switch iptables rules

---

## DHCP, Firewall, LAN Routing
- **DHCP:** Provided by dnsmasq on `eth0`
- **Firewall:** UFW with rules for SSH/XRDP from LAN
- **Check status:**
  ```sh
  systemctl status dnsmasq
  ufw status verbose
  iptables -L -n -v
  ```

---

## Reverse SSH Tunnel (autossh)
- **Service:** `vpnpi-reverse-ssh.service` (systemd)
- **Script:** `/usr/local/bin/vpnpi-reverse-ssh.sh`
- **Key:** `/root/.ssh/id_vpnpi_vhost`
- **Known hosts:** `/root/.ssh/known_hosts_vpnpi` (static, deployed by Ansible)
- **Remote ports:**
    - SSH: 22221 (binds to 0.0.0.0)
    - RDP: 33891 (binds to 0.0.0.0)
- **GatewayPorts:** Must be set to `yes` in `/etc/ssh/sshd_config` on the remote host for external access.
- **Forwarded ports:** The reverse SSH tunnel uses `-R 0.0.0.0:PORT:localhost:PORT` to bind forwarded ports externally. This allows connections from any host to the remote port (e.g., SSH: 22221, RDP: 33891).
- **Check status and logs:**
  ```sh
  systemctl status vpnpi-reverse-ssh.service
  journalctl -u vpnpi-reverse-ssh.service
  ps aux | grep autossh
  tail -f /var/run/vpnpi-reverse-ssh.status -f
  ```
- **Validate tunnel externally:**
  - On remote host, check:
    ```sh
    sudo lsof -iTCP:22221 -sTCP:LISTEN
    sudo lsof -iTCP:33891 -sTCP:LISTEN
    # Should show TCP *:22221 (LISTEN) and TCP *:33891 (LISTEN)
    ```
  - From another machine, connect to remote host's IP on those ports:
    ```sh
    ssh -p 22221 <user>@<remote-host-ip>
    # or use RDP client to <remote-host-ip>:33891
    ```
- **If tunnel fails or is not externally accessible:**
  - Confirm `GatewayPorts yes` is set and sshd restarted
  - Confirm autossh is using `-R 0.0.0.0:PORT:localhost:PORT`
  - Check firewall on remote host allows incoming connections to 22221/33891
  - Check interface (`wwan0`/`wlan1`) is up and has internet
  - Check private key permissions (`0600`)
  - Check remote server's `authorized_keys`
  - Add `-v` to autossh/ssh in script for debug
  - Systemd will restart the service if the tunnel fails; check logs for repeated failures

---

## General Troubleshooting Steps
1. **Check all interfaces:** `ip a`, `nmcli device status`
2. **Check systemd service status:** `systemctl status <service>`
3. **View logs:** `journalctl -u <service>`
4. **Check firewall/NAT:** `ufw status`, `iptables -L -n -v`
5. **Check VPN tunnel:** `ip a`, `systemctl status openvpn-client@vpnpi`
6. **Check Ansible playbook output for errors**
7. **Reboot if hardware/udev changes were made**

---

## If All Else Fails
- Re-run Ansible roles step by step using tags (see `deploy.yml`)
- Check `/etc/udev/rules.d/`, `/etc/netplan/`, `/etc/NetworkManager/`, `/etc/openvpn/`, `/etc/dnsmasq.conf`, `/etc/systemd/system/`
- Seek help with logs and config snippets