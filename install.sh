#!/bin/bash
# WiFi Manager Installation Script for Raspberry Pi
# This script installs and configures the WiFi Manager application

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables
HOTSPOT_SSID="JLBMaritime-AIS"
HOTSPOT_PASSWORD="Admin"
HOTSPOT_CHANNEL=7
HOTSPOT_IP="192.168.4.1"
HOTSPOT_NETMASK="255.255.255.0"
DHCP_RANGE_START="192.168.4.2"
DHCP_RANGE_END="192.168.4.20"
INSTALL_DIR="/opt/wifi-manager"
SERVICE_NAME="wifi-manager"

echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}WiFi Manager Installation Script${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Please run: sudo bash install.sh"
    exit 1
fi

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo 2>/dev/null; then
    echo -e "${YELLOW}Warning: This does not appear to be a Raspberry Pi${NC}"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo -e "${GREEN}Step 1: Updating system packages...${NC}"
apt-get update
apt-get upgrade -y

echo -e "${GREEN}Step 2: Installing required packages...${NC}"
apt-get install -y \
    python3 \
    python3-pip \
    hostapd \
    dnsmasq \
    network-manager \
    avahi-daemon \
    git

echo -e "${GREEN}Step 3: Installing Python dependencies...${NC}"
pip3 install --break-system-packages Flask Flask-HTTPAuth netifaces || pip3 install Flask Flask-HTTPAuth netifaces

echo -e "${GREEN}Step 4: Creating installation directory structure...${NC}"
# Create main directory
mkdir -p $INSTALL_DIR

# Create subdirectories
mkdir -p $INSTALL_DIR/app
mkdir -p $INSTALL_DIR/app/templates
mkdir -p $INSTALL_DIR/app/static
mkdir -p $INSTALL_DIR/app/static/css
mkdir -p $INSTALL_DIR/app/static/js
mkdir -p $INSTALL_DIR/cli
mkdir -p $INSTALL_DIR/config

echo -e "${GREEN}Step 5: Copying application files...${NC}"
# Copy main application files
cp run.py $INSTALL_DIR/
cp requirements.txt $INSTALL_DIR/
cp README.md $INSTALL_DIR/ 2>/dev/null || echo "README.md not found, skipping..."

# Copy app directory files
cp app/__init__.py $INSTALL_DIR/app/
cp app/routes.py $INSTALL_DIR/app/
cp app/wifi_manager.py $INSTALL_DIR/app/
cp app/network_diagnostics.py $INSTALL_DIR/app/
cp app/database.py $INSTALL_DIR/app/

# Copy templates
cp app/templates/index.html $INSTALL_DIR/app/templates/

# Copy static files
cp app/static/css/style.css $INSTALL_DIR/app/static/css/
cp app/static/js/app.js $INSTALL_DIR/app/static/js/

# Copy logo if it exists
if [ -f logo.png ]; then
    cp logo.png $INSTALL_DIR/app/static/
    echo "Logo copied"
elif [ -f app/static/logo.png ]; then
    cp app/static/logo.png $INSTALL_DIR/app/static/
    echo "Logo copied from static directory"
else
    echo -e "${YELLOW}Warning: logo.png not found. Please add it to $INSTALL_DIR/app/static/ later${NC}"
fi

# Copy CLI files
cp cli/wifi_cli.py $INSTALL_DIR/cli/

# Set permissions
chmod +x $INSTALL_DIR/run.py
chmod +x $INSTALL_DIR/cli/wifi_cli.py

# Change to installation directory
cd $INSTALL_DIR

echo "Files copied to $INSTALL_DIR"

echo -e "${GREEN}Step 6: Configuring hostapd (WiFi hotspot)...${NC}"

# Stop services
systemctl stop hostapd 2>/dev/null || true
systemctl stop dnsmasq 2>/dev/null || true

# Backup existing configurations
if [ -f /etc/hostapd/hostapd.conf ]; then
    cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.backup
fi

# Create hostapd configuration
cat > /etc/hostapd/hostapd.conf <<EOF
# WiFi Manager Hotspot Configuration
interface=wlan1
driver=nl80211
ssid=$HOTSPOT_SSID
hw_mode=g
channel=$HOTSPOT_CHANNEL
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$HOTSPOT_PASSWORD
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

# Point hostapd to config file
sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

echo -e "${GREEN}Step 7: Configuring dnsmasq (DHCP server)...${NC}"

# Backup existing configuration
if [ -f /etc/dnsmasq.conf ]; then
    cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
fi

# Create dnsmasq configuration
cat > /etc/dnsmasq.conf <<EOF
# WiFi Manager DHCP Configuration
interface=wlan1
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,255.255.255.0,24h
domain=wlan
address=/wifi.local/$HOTSPOT_IP
EOF

echo -e "${GREEN}Step 8: Configuring wlan1 static IP...${NC}"

# Remove any existing wlan1 connection in NetworkManager
nmcli connection delete "Hotspot" 2>/dev/null || true
nmcli connection delete "wlan1" 2>/dev/null || true

# Create NetworkManager connection for wlan1
nmcli connection add type wifi ifname wlan1 con-name "Hotspot" autoconnect yes ssid "$HOTSPOT_SSID" -- \
    wifi-sec.key-mgmt none \
    ipv4.method manual \
    ipv4.address $HOTSPOT_IP/24

# Alternative: Add to dhcpcd.conf if using dhcpcd instead of NetworkManager
if [ -f /etc/dhcpcd.conf ]; then
    # Remove existing wlan1 configuration
    sed -i '/interface wlan1/,/^$/d' /etc/dhcpcd.conf
    
    # Add new configuration
    cat >> /etc/dhcpcd.conf <<EOF

# WiFi Manager wlan1 static IP
interface wlan1
    static ip_address=$HOTSPOT_IP/24
    nohook wpa_supplicant
EOF
fi

echo -e "${GREEN}Step 9: Configuring Avahi (for wifi.local domain)...${NC}"

# Ensure avahi-daemon is enabled
systemctl enable avahi-daemon
systemctl restart avahi-daemon

echo -e "${GREEN}Step 10: Creating systemd service...${NC}"

cat > /etc/systemd/system/${SERVICE_NAME}.service <<EOF
[Unit]
Description=WiFi Manager Web Server
After=network.target hostapd.service dnsmasq.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/run.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload

echo -e "${GREEN}Step 11: Enabling IP forwarding...${NC}"

# Enable IP forwarding
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
sysctl -p

# Add iptables rules for NAT (so hotspot clients can access internet via wlan0)
iptables -t nat -A POSTROUTING -o wlan0 -j MASQUERADE
iptables -A FORWARD -i wlan0 -o wlan1 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan1 -o wlan0 -j ACCEPT

# Save iptables rules
apt-get install -y iptables-persistent
netfilter-persistent save

echo -e "${GREEN}Step 12: Enabling and starting services...${NC}"

# Unmask and enable hostapd
systemctl unmask hostapd
systemctl enable hostapd

# Enable and start dnsmasq
systemctl enable dnsmasq

# Enable WiFi Manager service
systemctl enable ${SERVICE_NAME}

# Start services
systemctl start hostapd
systemctl start dnsmasq
systemctl start ${SERVICE_NAME}

echo ""
echo -e "${GREEN}======================================${NC}"
echo -e "${GREEN}Installation Complete!${NC}"
echo -e "${GREEN}======================================${NC}"
echo ""
echo -e "${YELLOW}Hotspot Configuration:${NC}"
echo "  SSID: $HOTSPOT_SSID"
echo "  Password: $HOTSPOT_PASSWORD"
echo "  IP Address: $HOTSPOT_IP"
echo ""
echo -e "${YELLOW}Web Interface:${NC}"
echo "  URL: http://wifi.local or http://$HOTSPOT_IP"
echo "  Username: JLBMaritime"
echo "  Password: Admin"
echo ""
echo -e "${YELLOW}CLI Access:${NC}"
echo "  Run: sudo python3 $INSTALL_DIR/cli/wifi_cli.py"
echo ""
echo -e "${YELLOW}Service Management:${NC}"
echo "  Status:  sudo systemctl status ${SERVICE_NAME}"
echo "  Stop:    sudo systemctl stop ${SERVICE_NAME}"
echo "  Start:   sudo systemctl start ${SERVICE_NAME}"
echo "  Restart: sudo systemctl restart ${SERVICE_NAME}"
echo "  Logs:    sudo journalctl -u ${SERVICE_NAME} -f"
echo ""
echo -e "${GREEN}Please reboot your Raspberry Pi to ensure all changes take effect.${NC}"
echo -e "${YELLOW}Reboot now? (y/n):${NC}"
read -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Rebooting..."
    reboot
fi
