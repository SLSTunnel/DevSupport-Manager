#!/bin/bash

# DevSupport-Manager Enhanced Installation Script
# Features: Domain Configuration, OpenVPN, BadVPN Support

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  DevSupport-Manager Installer${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Detect operating system
detect_os() {
    if [[ -f /etc/debian_version ]]; then
        OS="debian"
    elif [[ -f /etc/redhat-release ]]; then
        OS="redhat"
    elif [[ -f /etc/arch-release ]]; then
        OS="arch"
    else
        print_error "Unsupported operating system"
        exit 1
    fi
    
    print_status "Detected OS: $OS"
}

# Install dependencies
install_dependencies() {
    print_status "Installing dependencies..."
    
    case $OS in
        "debian")
            apt-get update
            apt-get install -y curl wget git cmake build-essential certbot
            ;;
        "redhat")
            yum update -y
            yum install -y curl wget git cmake gcc gcc-c++ certbot
            ;;
        "arch")
            pacman -Syu --noconfirm
            pacman -S --noconfirm curl wget git cmake base-devel certbot
            ;;
    esac
    
    print_status "Dependencies installed"
}

# Configure SSH
configure_ssh() {
    print_status "Configuring SSH..."
    
    # Backup original SSH config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
    
    # Download enhanced SSH configuration
    wget -O /etc/ssh/sshd_config https://raw.githubusercontent.com/SLSTunnel/DevSupport-Manager/refs/heads/main/ssh > /dev/null 2>&1
    
    # Restart SSH service
    systemctl restart sshd || service sshd restart || systemctl restart ssh || service ssh restart
    
    print_status "SSH configured and restarted"
}

# Configure domain
configure_domain() {
    echo ""
    echo -e "${YELLOW}Domain Configuration${NC}"
    echo "========================"
    echo "Enter your domain name for SSL certificate generation"
    echo "Leave blank to skip domain configuration"
    echo ""
    
    read -p "Domain name (e.g., example.com): " DOMAIN_NAME
    
    if [[ -n "$DOMAIN_NAME" ]]; then
        # Create domain configuration file
        mkdir -p /etc/devsupport
        cat > /etc/devsupport/domain.conf << EOF
# DevSupport-Manager Domain Configuration
DOMAIN=$DOMAIN_NAME
SSL_CERT=/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem
SSL_KEY=/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem
EOF
        
        print_status "Domain configuration saved: $DOMAIN_NAME"
        
        # Generate SSL certificate
        print_status "Generating SSL certificate..."
        certbot certonly --standalone -d $DOMAIN_NAME --non-interactive --agree-tos --email admin@$DOMAIN_NAME
        
        if [[ $? -eq 0 ]]; then
            print_status "SSL certificate generated successfully"
        else
            print_warning "SSL certificate generation failed. You can try again later with:"
            echo "certbot certonly --standalone -d $DOMAIN_NAME"
        fi
    else
        print_warning "Domain configuration skipped"
    fi
}

# Install OpenVPN
install_openvpn() {
    print_status "Installing OpenVPN..."
    
    case $OS in
        "debian")
            apt-get install -y openvpn easy-rsa apache2-utils
            ;;
        "redhat")
            yum install -y openvpn easy-rsa httpd-tools
            ;;
        "arch")
            pacman -S --noconfirm openvpn easy-rsa apache
            ;;
    esac
    
    # Create OpenVPN directory structure
    mkdir -p /etc/openvpn/{server,client,keys,ws,proxy}
    
    # Create username/password file
    cat > /etc/openvpn/server/auth.txt << EOF
# OpenVPN Username/Password Authentication
# Format: username password
# Example: user1 password123
EOF
    
    chmod 600 /etc/openvpn/server/auth.txt
    
    # Generate OpenVPN configuration for UDP (port 1194)
    cat > /etc/openvpn/server.conf << EOF
# OpenVPN Server Configuration - UDP Port 1194
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh2048.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
tls-auth ta.key 0
cipher AES-256-CBC
auth SHA256
comp-lzo
user nobody
group nobody
persist-key
persist-tun
status openvpn-status.log
verb 3
explicit-exit-notify 1
auth-user-pass-verify /etc/openvpn/server/check_auth.sh via-file
username-as-common-name
script-security 2
EOF
    
    # Generate OpenVPN configuration for WebSocket over SSL (port 443)
    cat > /etc/openvpn/server-ws.conf << EOF
# OpenVPN Server Configuration - WebSocket over SSL Port 443
port 443
proto tcp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh2048.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
tls-auth ta.key 0
cipher AES-256-CBC
auth SHA256
comp-lzo
user nobody
group nobody
persist-key
persist-tun
status openvpn-status-ws.log
verb 3
explicit-exit-notify 1
auth-user-pass-verify /etc/openvpn/server/check_auth.sh via-file
username-as-common-name
script-security 2
EOF
    
    # Generate OpenVPN configuration for Proxy (port 8080)
    cat > /etc/openvpn/server-proxy.conf << EOF
# OpenVPN Server Configuration - Proxy Port 8080
port 8080
proto tcp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh2048.pem
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
keepalive 10 120
tls-auth ta.key 0
cipher AES-256-CBC
auth SHA256
comp-lzo
user nobody
group nobody
persist-key
persist-tun
status openvpn-status-proxy.log
verb 3
explicit-exit-notify 1
auth-user-pass-verify /etc/openvpn/server/check_auth.sh via-file
username-as-common-name
script-security 2
EOF
    
    # Create authentication check script
    cat > /etc/openvpn/server/check_auth.sh << 'EOF'
#!/bin/bash
# OpenVPN Authentication Check Script

AUTH_FILE="/etc/openvpn/server/auth.txt"
USERNAME="$1"
PASSWORD="$2"

# Check if username and password match
if grep -q "^$USERNAME $PASSWORD$" "$AUTH_FILE"; then
    exit 0
else
    exit 1
fi
EOF
    
    chmod +x /etc/openvpn/server/check_auth.sh
    
    # Create WebSocket proxy script
    cat > /etc/openvpn/server/ws-proxy.sh << 'EOF'
#!/bin/bash
# OpenVPN WebSocket Proxy Script

# Install required packages
if command -v apt-get &> /dev/null; then
    apt-get install -y python3 python3-pip
elif command -v yum &> /dev/null; then
    yum install -y python3 python3-pip
elif command -v pacman &> /dev/null; then
    pacman -S --noconfirm python3 python3-pip
fi

# Install WebSocket proxy
pip3 install websockify

# Create WebSocket proxy configuration
cat > /etc/openvpn/server/ws-proxy.py << 'PYEOF'
#!/usr/bin/env python3
import sys
import os
sys.path.insert(0, '/usr/local/lib/python3.*/dist-packages/')
import websockify

if __name__ == '__main__':
    websockify.WebSocketProxy(
        listen_host='0.0.0.0',
        listen_port=443,
        target_host='127.0.0.1',
        target_port=1194,
        cert='/etc/letsencrypt/live/yourdomain.com/fullchain.pem',
        key='/etc/letsencrypt/live/yourdomain.com/privkey.pem'
    ).start_server()
PYEOF

chmod +x /etc/openvpn/server/ws-proxy.py
EOF
    
    chmod +x /etc/openvpn/server/ws-proxy.sh
    
    print_status "OpenVPN installed and configured with multiple protocols"
    print_status "Ports: 1194 (UDP), 443 (WebSocket/SSL), 8080 (Proxy)"
}

# Install BadVPN
install_badvpn() {
    print_status "Installing BadVPN..."
    
    # Clone BadVPN repository
    cd /tmp
    git clone https://github.com/ambrop72/badvpn.git
    cd badvpn
    
    # Create build directory
    mkdir build
    cd build
    
    # Configure and build
    cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
    make install
    
    # Create systemd service for BadVPN
    cat > /etc/systemd/system/badvpn.service << EOF
[Unit]
Description=BadVPN UDP Gateway
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/local/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    
    # Enable and start BadVPN service
    systemctl daemon-reload
    systemctl enable badvpn
    systemctl start badvpn
    
    print_status "BadVPN installed and started on port 7300"
}

# Create DevSupport-Manager directory structure
create_directories() {
    print_status "Creating directory structure..."
    
    mkdir -p /etc/devsupport/{config,logs,scripts}
    mkdir -p /var/log/devsupport
    mkdir -p /usr/local/bin/devsupport
    
    print_status "Directory structure created"
}

# Main installation function
main_install() {
    print_header
    
    check_root
    detect_os
    install_dependencies
    configure_ssh
    create_directories
    configure_domain
    install_openvpn
    install_badvpn
    
    # Download and install architecture-specific binary
case "$(uname -m)" in
  x86_64)
            print_status "Detected x86_64 architecture."
            curl -L -o 64install.sh "https://github.com/SLSTunnel/DevSupport-Manager/raw/refs/heads/main/64install.sh" && chmod +x 64install.sh && sudo ./64install.sh && rm 64install.sh
    ;;
  aarch64 | arm64)
            print_status "Detected ARM architecture."
            curl -L -o arminstall.sh "https://github.com/SLSTunnel/DevSupport-Manager/raw/refs/heads/main/arminstall.sh" && chmod +x arminstall.sh && sudo ./arminstall.sh && rm arminstall.sh
    ;;
  *)
            print_error "Unsupported architecture: $(uname -m)"
    exit 1
    ;;
esac
    
    # Create post-installation script
    cat > /usr/local/bin/devsupport/post-install.sh << 'EOF'
#!/bin/bash

echo "=========================================="
echo "  DevSupport-Manager Installation Complete"
echo "=========================================="
echo ""
echo "✅ SSH Configuration: Updated"
echo "✅ OpenVPN: Installed and configured"
echo "✅ BadVPN: Installed and running on port 7300"
echo "✅ Domain Configuration: Ready"
echo ""
echo "📋 Next Steps:"
echo "1. Run 'sudo menu' to access the management panel"
echo "2. Configure your domain SSL certificate:"
echo "   certbot certonly --standalone -d yourdomain.com"
echo "3. Generate OpenVPN certificates:"
echo "   /usr/local/bin/devsupport/setup-openvpn.sh"
echo "4. Configure BadVPN clients to use port 7300"
echo ""
echo "🔧 Management Commands:"
echo "- sudo menu (Main management panel)"
echo "- sudo systemctl status openvpn@udp"
echo "- sudo systemctl status openvpn@ws"
echo "- sudo systemctl status openvpn@proxy"
echo "- sudo systemctl status badvpn"
echo "- sudo journalctl -u openvpn@udp"
echo ""
EOF
    
    chmod +x /usr/local/bin/devsupport/post-install.sh
    
    # Create OpenVPN setup script
    cat > /usr/local/bin/devsupport/setup-openvpn.sh << 'EOF'
#!/bin/bash

# OpenVPN Multi-Protocol Setup Script
echo "=========================================="
echo "  OpenVPN Multi-Protocol Setup"
echo "=========================================="

# Generate certificates
echo "Generating OpenVPN certificates..."
cd /etc/openvpn/easy-rsa
./easyrsa init-pki
./easyrsa build-ca nopass
./easyrsa build-server-full server nopass
./easyrsa gen-dh
openvpn --genkey --secret ta.key

# Copy certificates to server directory
cp pki/ca.crt /etc/openvpn/server/
cp pki/issued/server.crt /etc/openvpn/server/
cp pki/private/server.key /etc/openvpn/server/
cp ta.key /etc/openvpn/server/
cp pki/dh.pem /etc/openvpn/server/dh2048.pem

# Create systemd services for different protocols
echo "Creating systemd services..."

# UDP Service (Port 1194)
cat > /etc/systemd/system/openvpn@udp.service << 'SERVICEEOF'
[Unit]
Description=OpenVPN UDP Server on port 1194
After=network.target

[Service]
Type=notify
PrivateTmp=true
ExecStart=/usr/sbin/openvpn --config /etc/openvpn/server.conf
Restart=always

[Install]
WantedBy=multi-user.target
SERVICEEOF

# WebSocket Service (Port 443)
cat > /etc/systemd/system/openvpn@ws.service << 'SERVICEEOF'
[Unit]
Description=OpenVPN WebSocket Server on port 443
After=network.target

[Service]
Type=notify
PrivateTmp=true
ExecStart=/usr/sbin/openvpn --config /etc/openvpn/server-ws.conf
Restart=always

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Proxy Service (Port 8080)
cat > /etc/systemd/system/openvpn@proxy.service << 'SERVICEEOF'
[Unit]
Description=OpenVPN Proxy Server on port 8080
After=network.target

[Service]
Type=notify
PrivateTmp=true
ExecStart=/usr/sbin/openvpn --config /etc/openvpn/server-proxy.conf
Restart=always

[Install]
WantedBy=multi-user.target
SERVICEEOF

# WebSocket Proxy Service
cat > /etc/systemd/system/openvpn-ws-proxy.service << 'SERVICEEOF'
[Unit]
Description=OpenVPN WebSocket Proxy
After=network.target

[Service]
Type=simple
User=nobody
ExecStart=/usr/bin/python3 /etc/openvpn/server/ws-proxy.py
Restart=always

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Reload systemd
systemctl daemon-reload

# Start services
echo "Starting OpenVPN services..."
systemctl enable openvpn@udp
systemctl start openvpn@udp

systemctl enable openvpn@ws
systemctl start openvpn@ws

systemctl enable openvpn@proxy
systemctl start openvpn@proxy

# Setup WebSocket proxy if domain is configured
if [[ -f /etc/devsupport/domain.conf ]]; then
    DOMAIN=$(grep DOMAIN /etc/devsupport/domain.conf | cut -d'=' -f2)
    if [[ -n "$DOMAIN" ]]; then
        echo "Setting up WebSocket proxy for domain: $DOMAIN"
        sed -i "s/yourdomain.com/$DOMAIN/g" /etc/openvpn/server/ws-proxy.py
        systemctl enable openvpn-ws-proxy
        systemctl start openvpn-ws-proxy
    fi
fi

echo ""
echo "✅ OpenVPN Multi-Protocol Setup Complete!"
echo ""
echo "📋 Service Status:"
echo "- UDP Server (Port 1194): $(systemctl is-active openvpn@udp)"
echo "- WebSocket Server (Port 443): $(systemctl is-active openvpn@ws)"
echo "- Proxy Server (Port 8080): $(systemctl is-active openvpn@proxy)"
echo "- WebSocket Proxy: $(systemctl is-active openvpn-ws-proxy)"
echo ""
echo "🔧 Management Commands:"
echo "- sudo systemctl status openvpn@udp"
echo "- sudo systemctl status openvpn@ws"
echo "- sudo systemctl status openvpn@proxy"
echo "- sudo systemctl status openvpn-ws-proxy"
echo ""
echo "👤 Add users with: sudo /usr/local/bin/devsupport/add-openvpn-user.sh"
echo ""
EOF
    
    chmod +x /usr/local/bin/devsupport/setup-openvpn.sh
    
    print_status "Installation completed successfully!"
    print_status "Run '/usr/local/bin/devsupport/post-install.sh' for next steps"
}

# Run main installation
main_install

