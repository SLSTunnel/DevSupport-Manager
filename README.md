# DevSupport-Manager

A comprehensive server management tool with advanced networking capabilities, domain configuration, and VPN support.

## 🚀 Features

### Core Management
- **SSH WebSocket Proxy**: Tunnels SSH traffic over WebSockets with custom port selection
- **SSH over SSL/TLS**: Encapsulates SSH connections in TLS for enhanced security
- **User Management**: Create, manage, and control user access to servers
- **Integrated Xray Panel**: Advanced proxy capabilities for privacy and circumvention

### Advanced Networking
- **OpenVPN Multi-Protocol**: Complete OpenVPN server with multiple protocols
  - **UDP Server**: Port 1194 for standard OpenVPN connections
  - **WebSocket over SSL**: Port 443 for WebSocket-based connections
  - **Proxy Server**: Port 8080 for proxy-based connections
  - **Username/Password Authentication**: Secure user authentication system
- **BadVPN Support**: UDP gateway for gaming and streaming optimization
- **Domain Configuration**: Automatic SSL certificate management with Let's Encrypt
- **Multi-Architecture Support**: x86_64 and ARM64 compatibility

### Security Features
- **SSL/TLS Encryption**: Automatic certificate generation and renewal
- **Firewall Management**: Advanced firewall configuration and monitoring
- **Access Control**: Granular user permissions and session management
- **Multi-Protocol Security**: Different security levels for different protocols

## 📋 Requirements

- Linux server (Debian, Ubuntu, CentOS, RHEL, Arch Linux)
- Root access or sudo privileges
- Internet connection for package installation
- Domain name (optional, for SSL certificates)

## 🛠️ Installation

### Quick Install
```bash
curl -sSL https://raw.githubusercontent.com/SLSTunnel/DevSupport-Manager/main/install.sh | sudo bash
```

### Manual Install
```bash
# Clone the repository
git clone https://github.com/SLSTunnel/DevSupport-Manager.git
cd DevSupport-Manager

# Run the installer
sudo bash install.sh
```

## 🔧 Configuration

### Domain Setup
During installation, you'll be prompted to enter your domain name. This enables:
- Automatic SSL certificate generation
- Secure HTTPS access
- Professional domain-based access
- WebSocket proxy support

### OpenVPN Configuration
After installation, generate OpenVPN certificates and setup services:
```bash
sudo /usr/local/bin/devsupport/setup-openvpn.sh
```

#### OpenVPN Protocols Available:

**1. UDP Server (Port 1194)**
- Standard OpenVPN protocol
- Best performance for most use cases
- Compatible with all OpenVPN clients

**2. WebSocket over SSL (Port 443)**
- WebSocket-based connections
- Bypasses restrictive firewalls
- Works through HTTP/HTTPS proxies
- Requires domain SSL certificate

**3. Proxy Server (Port 8080)**
- TCP-based proxy connections
- Alternative to standard OpenVPN
- Useful for restrictive networks

#### User Management:
```bash
# Add new user
sudo /usr/local/bin/devsupport/add-openvpn-user.sh

# Or use the configuration manager
sudo bash config-manager.sh
```

### BadVPN Configuration
BadVPN is automatically installed and configured on port 7300. Configure your clients to use:
- Server: Your server IP
- Port: 7300
- Protocol: UDP

## 📖 Usage

### Main Management Panel
```bash
sudo menu
```

### OpenVPN Management
```bash
# Check all OpenVPN services
sudo systemctl status openvpn@udp
sudo systemctl status openvpn@ws
sudo systemctl status openvpn@proxy
sudo systemctl status openvpn-ws-proxy

# Restart services
sudo systemctl restart openvpn@udp
sudo systemctl restart openvpn@ws
sudo systemctl restart openvpn@proxy
sudo systemctl restart openvpn-ws-proxy

# View logs
sudo journalctl -u openvpn@udp -f
sudo journalctl -u openvpn@ws -f
sudo journalctl -u openvpn@proxy -f
sudo journalctl -u openvpn-ws-proxy -f
```

### User Management
```bash
# Add user with username/password
echo "username password" >> /etc/openvpn/server/auth.txt

# Remove user
sed -i "/^username /d" /etc/openvpn/server/auth.txt

# List users
cat /etc/openvpn/server/auth.txt
```

### Service Management
```bash
# Check BadVPN status
sudo systemctl status badvpn

# View OpenVPN logs
sudo journalctl -u openvpn@udp

# Restart services
sudo systemctl restart openvpn@udp
sudo systemctl restart badvpn
```

### SSL Certificate Management
```bash
# Generate SSL certificate
sudo certbot certonly --standalone -d yourdomain.com

# Renew certificates
sudo certbot renew

# Check certificate status
sudo certbot certificates
```

## 🗂️ Directory Structure

```
/etc/devsupport/
├── config/          # Configuration files
├── logs/           # Log files
├── scripts/        # Utility scripts
└── domain.conf     # Domain configuration

/usr/local/bin/devsupport/
├── post-install.sh     # Post-installation guide
├── setup-openvpn.sh    # OpenVPN setup script
└── add-openvpn-user.sh # User management script

/etc/openvpn/
├── server/         # Server certificates and configs
│   ├── auth.txt    # Username/password file
│   ├── server.conf # UDP configuration
│   ├── server-ws.conf # WebSocket configuration
│   ├── server-proxy.conf # Proxy configuration
│   └── check_auth.sh # Authentication script
├── client/         # Client configurations
└── keys/           # Key files
```

## 🔒 Security Considerations

### Firewall Configuration
The installer automatically configures basic firewall rules. For production use, consider:
- Restricting SSH access to specific IPs
- Configuring fail2ban for brute force protection
- Regular security updates

### SSL/TLS Security
- Certificates are automatically renewed
- Uses strong encryption (AES-256-CBC, SHA256)
- TLS 1.2+ support

### VPN Security
- OpenVPN uses industry-standard encryption
- Username/password authentication
- Multiple protocol support for different security needs
- BadVPN provides additional UDP optimization
- All traffic is encrypted end-to-end

## 🐛 Troubleshooting

### Common Issues

**OpenVPN won't start:**
```bash
# Check certificate files
ls -la /etc/openvpn/server/

# Regenerate certificates
sudo /usr/local/bin/devsupport/setup-openvpn.sh

# Check service status
sudo systemctl status openvpn@udp
sudo systemctl status openvpn@ws
sudo systemctl status openvpn@proxy
```

**WebSocket proxy issues:**
```bash
# Check domain configuration
cat /etc/devsupport/domain.conf

# Check WebSocket proxy status
sudo systemctl status openvpn-ws-proxy

# Update domain in WebSocket proxy
sudo sed -i "s/yourdomain.com/your-actual-domain.com/g" /etc/openvpn/server/ws-proxy.py
```

**User authentication problems:**
```bash
# Check auth file
cat /etc/openvpn/server/auth.txt

# Check auth script permissions
ls -la /etc/openvpn/server/check_auth.sh

# Test authentication
sudo /etc/openvpn/server/check_auth.sh username password
```

**BadVPN connection issues:**
```bash
# Check if BadVPN is running
sudo systemctl status badvpn

# Check port availability
sudo netstat -tulpn | grep 7300
```

**SSL certificate problems:**
```bash
# Check certificate validity
sudo certbot certificates

# Renew certificates
sudo certbot renew --force-renewal
```

### Log Files
- OpenVPN UDP logs: `sudo journalctl -u openvpn@udp`
- OpenVPN WebSocket logs: `sudo journalctl -u openvpn@ws`
- OpenVPN Proxy logs: `sudo journalctl -u openvpn@proxy`
- WebSocket Proxy logs: `sudo journalctl -u openvpn-ws-proxy`
- BadVPN logs: `sudo journalctl -u badvpn`
- System logs: `/var/log/syslog`

## 🔄 Updates

To update DevSupport-Manager:
```bash
# Backup current configuration
sudo cp -r /etc/devsupport /etc/devsupport.backup

# Run installer again
curl -sSL https://raw.githubusercontent.com/SLSTunnel/DevSupport-Manager/main/install.sh | sudo bash
```

## 📞 Support

For support and issues:
- Check the troubleshooting section above
- Review log files for error messages
- Ensure all dependencies are installed
- Verify firewall and network configuration

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## ⚠️ Disclaimer

This tool is for educational and legitimate server management purposes only. Users are responsible for complying with local laws and regulations regarding VPN usage and server management.

---

**DevSupport-Manager** - Advanced server management with networking capabilities







