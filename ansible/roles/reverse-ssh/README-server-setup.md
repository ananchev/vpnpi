# Reverse SSH Tunnel: Remote Server Setup

To allow external access to forwarded ports (SSH and XRDP) via the reverse SSH tunnel, you must configure the remote SSH server to bind forwarded ports to all interfaces (0.0.0.0), not just localhost.

## 1. Enable GatewayPorts

Edit the SSH server configuration file:

- **Linux/macOS:**
  - File: `/etc/ssh/sshd_config`
  - Add or update:
    ```
    GatewayPorts yes
    ```

- **Windows (OpenSSH):**
  - File: `C:\ProgramData\ssh\sshd_config`
  - Add or update:
    ```
    GatewayPorts yes
    ```

## 2. Restart SSH Service

After saving changes, restart the SSH daemon:

- **Linux:**
  ```sh
  sudo systemctl restart sshd
  ```
- **macOS:**
  ```sh
  sudo launchctl stop com.openssh.sshd
  sudo launchctl start com.openssh.sshd
  ```

## 3. Verify Port Binding

After restarting, forwarded ports (e.g., 22221, 33891) should be accessible from any host, not just localhost.

You can check with:
```sh
sudo netstat -tulnp | grep sshd
```

## 4. Security Note

Binding ports externally exposes them to the network. Ensure firewall and SSH authentication are properly configured.

---

**Summary:**
- Set `GatewayPorts yes` in `sshd_config`
- Restart SSH service (see above)
- Verify external port binding
- Secure your server
