# Quick Guide: Connect wlan1 to Wi-Fi from the Command Line

You can connect the `wlan1` interface to a Wi-Fi network directly from the terminal using NetworkManager's `nmcli` tool.

## 1. List available Wi-Fi networks on wlan1
```
nmcli device wifi list ifname wlan1
```

## 2. Connect to a Wi-Fi network
Replace `<SSID>` and `<PASSWORD>` with your Wi-Fi network's name and password:
```
nmcli device wifi connect "<SSID>" password "<PASSWORD>" ifname wlan1
```

## 3. Check connection status
```
nmcli device status
nmcli connection show --active
```

## 4. (Optional) Disconnect wlan1
```
nmcli device disconnect wlan1
```
## 5. (Optional) Delete wlan1 connection
```
nmcli connection show
nmcli connection delete <name-or-uuid>
```

---
