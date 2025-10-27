# JLBMaritime WiFi Manager

A comprehensive WiFi management system for Raspberry Pi 4B with hotspot capabilities and web-based interface.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Raspberry%20Pi-red)

## Features

- **Web-Based Interface**: Intuitive web UI accessible via hotspot
- **Network Scanning**: Scan and display available WiFi networks with signal strength
- **Connection Management**: Connect to networks with password support
- **Saved Networks**: Remember and manage previously connected networks
- **Network Diagnostics**: Built-in ping tests and network status monitoring
- **Real-Time Updates**: Live status updates via AJAX polling
- **HTTP Authentication**: Secure access with username/password
- **CLI Version**: Terminal-based interface for SSH access
- **Mobile Responsive**: Works seamlessly on desktop and mobile devices
- **Hotspot Mode**: wlan1 configured as access point, wlan0 for internet
- **Auto-Start**: Systemd service for automatic startup on boot

## System Requirements

### Hardware
- Raspberry Pi 4B (2GB or higher)
- Two WiFi interfaces (wlan0 and wlan1)
  - wlan0: Connect to internet
  - wlan1: Hotspot for web interface access

### Software
- Raspberry Pi OS (64-bit Bookworm)
- Python 3.9 or higher
- NetworkManager (nmcli)
- hostapd
- dnsmasq
- avahi-daemon

## Installation

### Quick Install

1. Clone this repository:
```bash
git clone [https://github.com/JLBMaritime/Hotspot_Wi-Fi_Manager.git]
cd wifi-manager
```

2. Run the installation script:
```bash
sudo bash install.sh
```

3. Reboot your Raspberry Pi:
```bash
sudo reboot
```

### Manual Installation

If you prefer to install manually:

1. Install system dependencies:
```bash
sudo apt-get update
sudo apt-get install -y python3 python3-pip hostapd dnsmasq network-manager avahi-daemon
```

2. Install Python dependencies:
```bash
pip3 install Flask Flask-HTTPAuth netifaces
```

3. Configure hotspot (see Configuration section below)

4. Create systemd service (see Service Management section below)

## Configuration

### Hotspot Settings

The default hotspot configuration is:
- **SSID**: JLBMaritime-AIS
- **Password**: Admin
- **IP Address**: 192.168.4.1
- **DHCP Range**: 192.168.4.2 - 192.168.4.20

To change these settings, edit the variables in `install.sh` before running it, or manually edit:
- `/etc/hostapd/hostapd.conf` - Hotspot SSID and password
- `/etc/dnsmasq.conf` - DHCP settings

### Web Interface Credentials

Default credentials:
- **Username**: JLBMaritime
- **Password**: Admin

To change, edit `app/__init__.py`:
```python
USERS = {
    "JLBMaritime": "Admin"  # Change these values
}
```

## Usage

### Web Interface

1. Connect to the WiFi hotspot:
   - SSID: `JLBMaritime-AIS`
   - Password: `Admin`

2. Open a web browser and navigate to:
   - `http://wifi.local` or
   - `http://192.168.4.1`

3. Log in with:
   - Username: `JLBMaritime`
   - Password: `Admin`

4. Use the interface to:
   - Scan for available networks
   - Connect to WiFi networks
   - View current connection status
   - Manage saved networks
   - Run network diagnostics

### CLI Version

Access via SSH and run:
```bash
sudo python3 /opt/wifi-manager/cli/wifi_cli.py
```

CLI Menu Options:
1. Scan for networks
2. Connect to network
3. Show current connection
4. List saved networks
5. Forget network
6. Run network diagnostics
7. Run ping test
8. Exit

## Service Management

### Check Status
```bash
sudo systemctl status wifi-manager
```

### Start Service
```bash
sudo systemctl start wifi-manager
```

### Stop Service
```bash
sudo systemctl stop wifi-manager
```

### Restart Service
```bash
sudo systemctl restart wifi-manager
```

### View Logs
```bash
sudo journalctl -u wifi-manager -f
```

### Enable Auto-Start
```bash
sudo systemctl enable wifi-manager
```

### Disable Auto-Start
```bash
sudo systemctl disable wifi-manager
```

## API Documentation

The web interface uses a REST API with the following endpoints:

### GET /api/scan
Scan for available WiFi networks.

**Response:**
```json
{
  "success": true,
  "networks": [
    {
      "ssid": "NetworkName",
      "signal": "75",
      "security": "Secured"
    }
  ]
}
```

### POST /api/rescan
Trigger a new network scan.

### GET /api/current
Get current connection information.

**Response:**
```json
{
  "success": true,
  "current": {
    "ssid": "ConnectedNetwork",
    "connection_name": "ConnectedNetwork"
  },
  "ip": "192.168.1.100"
}
```

### GET /api/saved
Get list of saved networks.

### POST /api/connect
Connect to a WiFi network.

**Request Body:**
```json
{
  "ssid": "NetworkName",
  "password": "password123"
}
```

### POST /api/forget
Forget a saved network.

**Request Body:**
```json
{
  "ssid": "NetworkName"
}
```

### POST /api/ping
Run a ping test.

**Request Body:**
```json
{
  "host": "8.8.8.8",
  "count": 4
}
```

### GET /api/diagnostics
Get comprehensive network diagnostics.

## Project Structure

```
wifi-manager/
├── app/
│   ├── __init__.py           # Flask app initialization
│   ├── routes.py             # API routes
│   ├── wifi_manager.py       # WiFi operations
│   ├── network_diagnostics.py # Network diagnostics
│   ├── database.py           # SQLite database
│   ├── templates/
│   │   └── index.html        # Web interface
│   └── static/
│       ├── css/
│       │   └── style.css     # Styling
│       ├── js/
│       │   └── app.js        # Frontend logic
│       └── logo.png          # Company logo
├── cli/
│   └── wifi_cli.py           # CLI version
├── config/
│   ├── hostapd.conf          # Hotspot config (created by install.sh)
│   └── dnsmasq.conf          # DHCP config (created by install.sh)
├── install.sh                # Installation script
├── requirements.txt          # Python dependencies
├── run.py                    # Application entry point
└── README.md                 # This file
```

## Troubleshooting

### Hotspot not appearing

1. Check if hostapd is running:
```bash
sudo systemctl status hostapd
```

2. Check wlan1 interface:
```bash
ip addr show wlan1
```

3. Restart hostapd:
```bash
sudo systemctl restart hostapd
```

### Cannot access web interface

1. Ensure you're connected to the hotspot
2. Try the IP address instead: `http://192.168.4.1`
3. Check if the service is running:
```bash
sudo systemctl status wifi-manager
```

### Cannot connect to networks

1. Verify NetworkManager is running:
```bash
sudo systemctl status NetworkManager
```

2. Check for errors in logs:
```bash
sudo journalctl -u wifi-manager -n 50
```

3. Try running with sudo:
```bash
sudo python3 /opt/wifi-manager/run.py
```

### wlan0 not connecting to internet

1. Check wlan0 status:
```bash
nmcli device status
```

2. Try manual connection:
```bash
sudo nmcli device wifi connect "SSID" password "password"
```

### Database errors

1. Remove and reinitialize database:
```bash
sudo rm /opt/wifi-manager/wifi_manager.db
sudo systemctl restart wifi-manager
```

## Security Considerations

- Change default credentials before deployment
- Use HTTPS for production (requires SSL certificate)
- Limit hotspot access to trusted devices
- Consider MAC address filtering for hotspot
- Keep system packages updated
- Review and restrict API access if needed

## Development

### Running in Development Mode

1. Install dependencies:
```bash
pip3 install -r requirements.txt
```

2. Run the application:
```bash
sudo python3 run.py
```

3. Access at `http://localhost:5000` (or port 80 if run with sudo)

### Modifying the Code

- **Frontend**: Edit `app/templates/index.html`, `app/static/css/style.css`, `app/static/js/app.js`
- **Backend**: Edit `app/routes.py`, `app/wifi_manager.py`, `app/network_diagnostics.py`
- **Database**: Edit `app/database.py`
- **Colors**: Modify CSS variables in `app/static/css/style.css`

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License.

## Support

For issues, questions, or contributions, please open an issue on GitHub.

## Changelog

### Version 1.0.0 (Initial Release)
- Web-based WiFi manager interface
- Hotspot configuration for Raspberry Pi
- Network scanning and connection management
- Saved networks with forget functionality
- Network diagnostics and ping tests
- CLI version for SSH access
- Real-time status updates
- Mobile-responsive design
- Systemd service integration

## Credits

Developed for JLBMaritime AIS ADS-B Project

---

**Raspberry Pi 4B | 64-bit Raspberry Pi OS (Bookworm) | Python 3 | Flask**

