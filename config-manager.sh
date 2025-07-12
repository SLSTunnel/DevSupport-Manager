#!/bin/bash

# DevSupport-Manager Configuration Manager
# Handles domain, OpenVPN, and BadVPN configuration

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
    echo -e "${BLUE}  DevSupport-Manager Config${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Domain management
manage_domain() {
    echo ""
    echo "🌐 Domain Management"
    echo "1. Configure new domain"
    echo "2. Update SSL certificate"
    echo "3. View current domain config"
    echo "4. Back to main menu"
    
    read -p "Select option: " domain_choice
    
    case $domain_choice in
        1)
            echo -e "${YELLOW}Enter your domain name (e.g., example.com):${NC}"
            read -p "Domain: " DOMAIN_NAME
            
            if [[ -n "$DOMAIN_NAME" ]]; then
                # Create domain configuration file
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
                print_status "SSL certificate generated successfully"
            else
                print_warning "No domain provided"
            fi
            ;;
        2)
            print_status "Updating SSL certificate..."
            certbot renew --force-renewal
            print_status "SSL certificate updated"
            ;;
        3)
            if [[ -f /etc/devsupport/domain.conf ]]; then
                echo ""
                echo "Current domain configuration:"
                cat /etc/devsupport/domain.conf
            else
                print_warning "No domain configuration found"
            fi
            ;;
        4)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

# OpenVPN management
manage_openvpn() {
    echo ""
    echo "🔐 OpenVPN Management"
    echo "1. Generate new certificates"
    echo "2. Manage users (add/remove)"
    echo "3. View all service status"
    echo "4. Restart all OpenVPN services"
    echo "5. View OpenVPN logs"
    echo "6. Setup WebSocket proxy"
    echo "7. Back to main menu"
    
    read -p "Select option: " openvpn_choice
    
    case $openvpn_choice in
        1)
            print_status "Generating OpenVPN certificates..."
            /usr/local/bin/devsupport/setup-openvpn.sh
            print_status "OpenVPN certificates generated"
            ;;
        2)
            echo ""
            echo "👤 User Management"
            echo "1. Add new user"
            echo "2. Remove user"
            echo "3. List users"
            echo "4. Change password"
            echo "5. Back to OpenVPN menu"
            
            read -p "Select option: " user_choice
            
            case $user_choice in
                1)
                    echo -e "${YELLOW}Enter username:${NC}"
                    read -p "Username: " USERNAME
                    read -s -p "Password: " PASSWORD
                    echo ""
                    
                    if [[ -n "$USERNAME" && -n "$PASSWORD" ]]; then
                        echo "$USERNAME $PASSWORD" >> /etc/openvpn/server/auth.txt
                        print_status "User '$USERNAME' added successfully"
                    else
                        print_warning "Username and password cannot be empty"
                    fi
                    ;;
                2)
                    echo -e "${YELLOW}Enter username to remove:${NC}"
                    read -p "Username: " USERNAME
                    
                    if [[ -n "$USERNAME" ]]; then
                        sed -i "/^$USERNAME /d" /etc/openvpn/server/auth.txt
                        print_status "User '$USERNAME' removed successfully"
                    else
                        print_warning "Username cannot be empty"
                    fi
                    ;;
                3)
                    echo ""
                    echo "📋 Current Users:"
                    if [[ -f /etc/openvpn/server/auth.txt ]]; then
                        cat /etc/openvpn/server/auth.txt | grep -v "^#"
                    else
                        print_warning "No users found"
                    fi
                    ;;
                4)
                    echo -e "${YELLOW}Enter username:${NC}"
                    read -p "Username: " USERNAME
                    read -s -p "New password: " NEW_PASSWORD
                    echo ""
                    
                    if [[ -n "$USERNAME" && -n "$NEW_PASSWORD" ]]; then
                        sed -i "s/^$USERNAME .*/$USERNAME $NEW_PASSWORD/" /etc/openvpn/server/auth.txt
                        print_status "Password for '$USERNAME' changed successfully"
                    else
                        print_warning "Username and password cannot be empty"
                    fi
                    ;;
                5)
                    return
                    ;;
                *)
                    print_error "Invalid option"
                    ;;
            esac
            ;;
        3)
            echo ""
            echo "📊 OpenVPN Service Status"
            echo "========================="
            echo "UDP Server (Port 1194): $(systemctl is-active openvpn@udp)"
            echo "WebSocket Server (Port 443): $(systemctl is-active openvpn@ws)"
            echo "Proxy Server (Port 8080): $(systemctl is-active openvpn@proxy)"
            echo "WebSocket Proxy: $(systemctl is-active openvpn-ws-proxy)"
            ;;
        4)
            print_status "Restarting all OpenVPN services..."
            systemctl restart openvpn@udp
            systemctl restart openvpn@ws
            systemctl restart openvpn@proxy
            systemctl restart openvpn-ws-proxy
            print_status "All OpenVPN services restarted"
            ;;
        5)
            echo ""
            echo "📋 Select log to view:"
            echo "1. UDP Server logs"
            echo "2. WebSocket Server logs"
            echo "3. Proxy Server logs"
            echo "4. WebSocket Proxy logs"
            
            read -p "Select option: " log_choice
            
            case $log_choice in
                1)
                    journalctl -u openvpn@udp -f
                    ;;
                2)
                    journalctl -u openvpn@ws -f
                    ;;
                3)
                    journalctl -u openvpn@proxy -f
                    ;;
                4)
                    journalctl -u openvpn-ws-proxy -f
                    ;;
                *)
                    print_error "Invalid option"
                    ;;
            esac
            ;;
        6)
            if [[ -f /etc/devsupport/domain.conf ]]; then
                DOMAIN=$(grep DOMAIN /etc/devsupport/domain.conf | cut -d'=' -f2)
                if [[ -n "$DOMAIN" ]]; then
                    print_status "Setting up WebSocket proxy for domain: $DOMAIN"
                    sed -i "s/yourdomain.com/$DOMAIN/g" /etc/openvpn/server/ws-proxy.py
                    systemctl enable openvpn-ws-proxy
                    systemctl start openvpn-ws-proxy
                    print_status "WebSocket proxy setup complete"
                else
                    print_warning "No domain configured"
                fi
            else
                print_warning "No domain configuration found"
            fi
            ;;
        7)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

# BadVPN management
manage_badvpn() {
    echo ""
    echo "🎮 BadVPN Management"
    echo "1. Check BadVPN status"
    echo "2. Restart BadVPN service"
    echo "3. Change BadVPN port"
    echo "4. View BadVPN logs"
    echo "5. Back to main menu"
    
    read -p "Select option: " badvpn_choice
    
    case $badvpn_choice in
        1)
            systemctl status badvpn
            ;;
        2)
            print_status "Restarting BadVPN service..."
            systemctl restart badvpn
            print_status "BadVPN service restarted"
            ;;
        3)
            echo -e "${YELLOW}Enter new port (default: 7300):${NC}"
            read -p "Port: " BADVPN_PORT
            
            if [[ -n "$BADVPN_PORT" ]]; then
                # Update BadVPN service file
                sed -i "s/--listen-addr 127.0.0.1:7300/--listen-addr 127.0.0.1:$BADVPN_PORT/" /etc/systemd/system/badvpn.service
                
                # Reload and restart service
                systemctl daemon-reload
                systemctl restart badvpn
                
                print_status "BadVPN port changed to $BADVPN_PORT"
            else
                print_warning "No port provided"
            fi
            ;;
        4)
            journalctl -u badvpn -f
            ;;
        5)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

# System information
show_system_info() {
    echo ""
    echo "📊 System Information"
    echo "===================="
    
    echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "Uptime: $(uptime -p)"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    echo "Memory: $(free -h | grep Mem | awk '{print $3"/"$2}')"
    echo "Disk Usage: $(df -h / | tail -1 | awk '{print $5}')"
    
    echo ""
    echo "🔧 Service Status"
    echo "================="
    
    echo "OpenVPN: $(systemctl is-active openvpn@server)"
    echo "BadVPN: $(systemctl is-active badvpn)"
    echo "SSH: $(systemctl is-active sshd)"
    
    echo ""
    echo "🌐 Network Information"
    echo "====================="
    
    echo "Public IP: $(curl -s ifconfig.me)"
    echo "Local IP: $(hostname -I | awk '{print $1}')"
    
    if [[ -f /etc/devsupport/domain.conf ]]; then
        echo "Domain: $(grep DOMAIN /etc/devsupport/domain.conf | cut -d'=' -f2)"
    fi
}

# Backup and restore
backup_restore() {
    echo ""
    echo "💾 Backup & Restore"
    echo "1. Create backup"
    echo "2. Restore backup"
    echo "3. Back to main menu"
    
    read -p "Select option: " backup_choice
    
    case $backup_choice in
        1)
            BACKUP_DIR="/root/devsupport-backup-$(date +%Y%m%d_%H%M%S)"
            mkdir -p $BACKUP_DIR
            
            print_status "Creating backup in $BACKUP_DIR"
            
            # Backup configurations
            cp -r /etc/devsupport $BACKUP_DIR/
            cp -r /etc/openvpn $BACKUP_DIR/
            cp /etc/systemd/system/badvpn.service $BACKUP_DIR/
            
            # Create backup archive
            tar -czf $BACKUP_DIR.tar.gz -C /root $(basename $BACKUP_DIR)
            rm -rf $BACKUP_DIR
            
            print_status "Backup created: $BACKUP_DIR.tar.gz"
            ;;
        2)
            echo -e "${YELLOW}Enter backup file path:${NC}"
            read -p "Backup file: " BACKUP_FILE
            
            if [[ -f "$BACKUP_FILE" ]]; then
                print_status "Restoring backup..."
                
                # Extract backup
                tar -xzf $BACKUP_FILE -C /tmp
                BACKUP_DIR=$(tar -tzf $BACKUP_FILE | head -1 | cut -d'/' -f1)
                
                # Restore configurations
                cp -r /tmp/$BACKUP_DIR/devsupport /etc/
                cp -r /tmp/$BACKUP_DIR/openvpn /etc/
                cp /tmp/$BACKUP_DIR/badvpn.service /etc/systemd/system/
                
                # Reload services
                systemctl daemon-reload
                systemctl restart badvpn
                systemctl restart openvpn@server
                
                rm -rf /tmp/$BACKUP_DIR
                
                print_status "Backup restored successfully"
            else
                print_error "Backup file not found"
            fi
            ;;
        3)
            return
            ;;
        *)
            print_error "Invalid option"
            ;;
    esac
}

# Main menu
main_menu() {
    while true; do
        print_header
        echo ""
        echo "1. 🌐 Domain Management"
        echo "2. 🔐 OpenVPN Management"
        echo "3. 🎮 BadVPN Management"
        echo "4. 📊 System Information"
        echo "5. 💾 Backup & Restore"
        echo "6. 🚪 Exit"
        echo ""
        
        read -p "Select option: " choice
        
        case $choice in
            1)
                manage_domain
                ;;
            2)
                manage_openvpn
                ;;
            3)
                manage_badvpn
                ;;
            4)
                show_system_info
                ;;
            5)
                backup_restore
                ;;
            6)
                print_status "Goodbye!"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Check if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_root
    main_menu
fi 