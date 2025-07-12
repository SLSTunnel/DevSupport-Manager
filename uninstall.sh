#!/bin/bash

# DevSupport-Manager Uninstaller
# Removes all installed components

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
    echo -e "${BLUE}  DevSupport-Manager Uninstaller${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Confirm uninstallation
confirm_uninstall() {
    echo ""
    print_warning "This will remove all DevSupport-Manager components including:"
    echo "- OpenVPN server and certificates"
    echo "- BadVPN service"
    echo "- Domain configurations"
    echo "- SSL certificates"
    echo "- All configuration files"
    echo ""
    echo -e "${RED}This action cannot be undone!${NC}"
    echo ""
    
    read -p "Are you sure you want to continue? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_status "Uninstallation cancelled"
        exit 0
    fi
}

# Stop and remove services
remove_services() {
    print_status "Stopping services..."
    
    # Stop OpenVPN
    systemctl stop openvpn@server 2>/dev/null || true
    systemctl disable openvpn@server 2>/dev/null || true
    
    # Stop BadVPN
    systemctl stop badvpn 2>/dev/null || true
    systemctl disable badvpn 2>/dev/null || true
    
    # Remove service files
    rm -f /etc/systemd/system/badvpn.service
    systemctl daemon-reload
    
    print_status "Services stopped and removed"
}

# Remove OpenVPN
remove_openvpn() {
    print_status "Removing OpenVPN..."
    
    # Remove OpenVPN packages
    if command -v apt-get &> /dev/null; then
        apt-get remove --purge -y openvpn easy-rsa
    elif command -v yum &> /dev/null; then
        yum remove -y openvpn easy-rsa
    elif command -v pacman &> /dev/null; then
        pacman -R --noconfirm openvpn easy-rsa
    fi
    
    # Remove OpenVPN directories
    rm -rf /etc/openvpn
    rm -rf /var/log/openvpn
    
    print_status "OpenVPN removed"
}

# Remove BadVPN
remove_badvpn() {
    print_status "Removing BadVPN..."
    
    # Remove BadVPN binary
    rm -f /usr/local/bin/badvpn-udpgw
    
    # Remove source files
    rm -rf /tmp/badvpn
    
    print_status "BadVPN removed"
}

# Remove SSL certificates
remove_ssl() {
    print_status "Removing SSL certificates..."
    
    # Remove Let's Encrypt certificates
    if [[ -d /etc/letsencrypt ]]; then
        rm -rf /etc/letsencrypt
    fi
    
    # Remove certbot
    if command -v apt-get &> /dev/null; then
        apt-get remove --purge -y certbot
    elif command -v yum &> /dev/null; then
        yum remove -y certbot
    elif command -v pacman &> /dev/null; then
        pacman -R --noconfirm certbot
    fi
    
    print_status "SSL certificates removed"
}

# Remove DevSupport-Manager files
remove_devsupport() {
    print_status "Removing DevSupport-Manager files..."
    
    # Remove main binary
    rm -f /usr/local/bin/menu
    
    # Remove configuration directories
    rm -rf /etc/devsupport
    rm -rf /var/log/devsupport
    rm -rf /usr/local/bin/devsupport
    
    # Remove scripts
    rm -f /usr/local/bin/config-manager.sh
    
    print_status "DevSupport-Manager files removed"
}

# Restore original SSH configuration
restore_ssh() {
    print_status "Restoring original SSH configuration..."
    
    # Find backup file
    BACKUP_FILE=$(ls /etc/ssh/sshd_config.backup.* 2>/dev/null | tail -1)
    
    if [[ -n "$BACKUP_FILE" ]]; then
        cp "$BACKUP_FILE" /etc/ssh/sshd_config
        systemctl restart sshd || service sshd restart || systemctl restart ssh || service ssh restart
        print_status "SSH configuration restored from backup"
    else
        print_warning "No SSH backup found, manual restoration may be required"
    fi
}

# Clean up dependencies
cleanup_dependencies() {
    print_status "Cleaning up dependencies..."
    
    # Remove build tools if no longer needed
    if command -v apt-get &> /dev/null; then
        apt-get autoremove -y
        apt-get autoclean
    elif command -v yum &> /dev/null; then
        yum autoremove -y
        yum clean all
    elif command -v pacman &> /dev/null; then
        pacman -Rns --noconfirm $(pacman -Qtdq) 2>/dev/null || true
    fi
    
    print_status "Dependencies cleaned up"
}

# Main uninstallation function
main_uninstall() {
    print_header
    
    check_root
    confirm_uninstall
    
    print_status "Starting uninstallation..."
    
    remove_services
    remove_openvpn
    remove_badvpn
    remove_ssl
    remove_devsupport
    restore_ssh
    cleanup_dependencies
    
    echo ""
    print_status "Uninstallation completed successfully!"
    echo ""
    echo "The following components have been removed:"
    echo "✅ OpenVPN server and certificates"
    echo "✅ BadVPN service"
    echo "✅ SSL certificates and Let's Encrypt"
    echo "✅ DevSupport-Manager configuration files"
    echo "✅ SSH configuration restored"
    echo ""
    echo "Note: You may need to manually remove any firewall rules"
    echo "that were added for OpenVPN or BadVPN."
}

# Run main uninstallation
main_uninstall 