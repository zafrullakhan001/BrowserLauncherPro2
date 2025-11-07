#!/bin/bash

# WSL Performance Tuning Script
# This script optimizes WSL performance by configuring various system parameters
# and settings specific to WSL environments.

# Function to print messages with colors
print_green() { echo -e "\e[32m$1\e[0m"; }
print_blue() { echo -e "\e[34m$1\e[0m"; }
print_red() { echo -e "\e[31m$1\e[0m"; }
print_yellow() { echo -e "\e[33m$1\e[0m"; }

# Function to check if running in WSL
check_wsl() {
    # Check for WSL using multiple methods
    local is_wsl=false
    
    # Method 1: Check /proc/version
    if grep -q "Microsoft" /proc/version 2>/dev/null; then
        is_wsl=true
    fi
    
    # Method 2: Check uname
    if uname -r | grep -q "microsoft" 2>/dev/null; then
        is_wsl=true
    fi
    
    # Method 3: Check for WSL specific files
    if [ -f /proc/sys/fs/binfmt_misc/WSLInterop ] || [ -f /proc/sys/fs/binfmt_misc/WSL2Interop ]; then
        is_wsl=true
    fi
    
    if [ "$is_wsl" = false ]; then
        print_red "Error: This script must be run in WSL"
        print_yellow "Please follow these steps:"
        print_yellow "1. Open WSL terminal (not from Windows path)"
        print_yellow "2. Navigate to your project directory"
        print_yellow "3. Run the script again"
        print_yellow ""
        print_yellow "Example:"
        print_yellow "  wsl"
        print_yellow "  cd ~/PS7333/wslscripts"
        print_yellow "  sudo ./wsl-performance-tune.sh"
        exit 1
    fi
    
    # Check if running from Windows path
    if [[ "$PWD" == /mnt/* ]]; then
        print_red "Warning: Script is running from Windows path (/mnt/c/...)"
        print_yellow "For best performance, please run this script from WSL filesystem"
        print_yellow "Current path: $PWD"
        print_yellow ""
        print_yellow "Would you like to continue anyway? (y/n)"
        read -r response
        if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            print_yellow "Please run the script from WSL filesystem instead"
            print_yellow "Example:"
            print_yellow "  wsl"
            print_yellow "  cd ~/PS7333/wslscripts"
            print_yellow "  sudo ./wsl-performance-tune.sh"
            exit 1
        fi
    fi
    
    # Print WSL version information
    print_blue "WSL Environment Information:"
    print_blue "Kernel: $(uname -r)"
    print_blue "WSL Version: $(grep -o "WSL[0-9]*" /proc/version 2>/dev/null || echo "WSL1")"
    print_blue "Current Directory: $PWD"
}

# Function to backup existing configurations
backup_configs() {
    print_blue "Backing up existing configurations..."
    local backup_dir="/etc/wsl-backup-$(date +%Y%m%d_%H%M%S)"
    sudo mkdir -p "$backup_dir"
    
    # Backup existing files
    [ -f /etc/sysctl.d/99-wsl-performance.conf ] && sudo cp /etc/sysctl.d/99-wsl-performance.conf "$backup_dir/"
    [ -f /etc/sysctl.d/99-wsl-network.conf ] && sudo cp /etc/sysctl.d/99-wsl-network.conf "$backup_dir/"
    [ -f /etc/sysctl.d/99-wsl-io.conf ] && sudo cp /etc/sysctl.d/99-wsl-io.conf "$backup_dir/"
    [ -f /etc/wsl.conf ] && sudo cp /etc/wsl.conf "$backup_dir/"
    
    print_green "✓ Configurations backed up to $backup_dir"
}

# Function to optimize swap settings
optimize_swap() {
    print_blue "Optimizing swap settings..."
    sudo tee /etc/sysctl.d/99-wsl-performance.conf > /dev/null << 'EOF'
# WSL Performance Settings
vm.swappiness=10
vm.dirty_ratio=60
vm.dirty_background_ratio=2
vm.dirty_expire_centisecs=500
vm.dirty_writeback_centisecs=100
EOF
    print_green "✓ Swap settings optimized"
}

# Function to optimize network settings
optimize_network() {
    print_blue "Optimizing network settings..."
    sudo tee /etc/sysctl.d/99-wsl-network.conf > /dev/null << 'EOF'
# WSL Network Settings
net.core.somaxconn=65535
net.ipv4.tcp_max_syn_backlog=65535
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=15
net.ipv4.tcp_keepalive_time=120
net.ipv4.tcp_keepalive_probes=5
net.ipv4.tcp_keepalive_intvl=15
EOF
    print_green "✓ Network settings optimized"
}

# Function to optimize disk I/O
optimize_disk_io() {
    print_blue "Optimizing disk I/O settings..."
    sudo tee /etc/sysctl.d/99-wsl-io.conf > /dev/null << 'EOF'
# WSL Disk I/O Settings
vm.dirty_background_bytes=16777216
vm.dirty_bytes=50331648
EOF
    print_green "✓ Disk I/O settings optimized"
}

# Function to configure WSL settings
configure_wsl() {
    print_blue "Configuring WSL settings..."
    sudo tee /etc/wsl.conf > /dev/null << 'EOF'
[automount]
enabled = true
options = "metadata,umask=22,fmask=11"
mountFsTab = true

[network]
generateHosts = true
generateResolvConf = true

[interop]
enabled = true
appendWindowsPath = true

[wsl2]
memory=4GB
processors=2
localhostForwarding=true
EOF
    print_green "✓ WSL settings configured"
}

# Function to create performance monitoring script
create_monitor_script() {
    print_blue "Creating performance monitoring script..."
    sudo tee /usr/local/bin/wsl-performance-monitor > /dev/null << 'EOF'
#!/bin/bash

# WSL Performance Monitor
# Monitors and reports system performance metrics

# Set up logging
LOG_FILE="/var/log/wsl-performance.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Set up colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Print header
echo -e "${YELLOW}=== WSL Performance Monitor ===${NC}"
echo -e "${YELLOW}Generated on: $(date)${NC}"
echo -e "${YELLOW}===============================${NC}"
echo ""

# Print system information
echo -e "${YELLOW}=== System Information ===${NC}"
echo "Hostname: $(hostname)"
echo "Kernel: $(uname -r)"
echo "Uptime: $(uptime -p)"
echo "Load Average: $(cat /proc/loadavg)"
echo ""

# Print CPU information
echo -e "${YELLOW}=== CPU Information ===${NC}"
echo "CPU Model: $(grep 'model name' /proc/cpuinfo | head -n1 | cut -d':' -f2 | sed 's/^[ \t]*//')"
echo "CPU Cores: $(grep -c 'processor' /proc/cpuinfo)"
echo "CPU Threads: $(grep 'siblings' /proc/cpuinfo | head -n1 | cut -d':' -f2 | sed 's/^[ \t]*//')"
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')"
echo ""

# Print memory information
echo -e "${YELLOW}=== Memory Information ===${NC}"
echo "Total Memory: $(free -h | grep Mem | awk '{print $2}')"
echo "Used Memory: $(free -h | grep Mem | awk '{print $3}')"
echo "Free Memory: $(free -h | grep Mem | awk '{print $4}')"
echo "Available Memory: $(free -h | grep Mem | awk '{print $7}')"
echo ""

# Print disk information
echo -e "${YELLOW}=== Disk Information ===${NC}"
echo "Root Disk Size: $(df -h / | tail -1 | awk '{print $2}')"
echo "Root Disk Used: $(df -h / | tail -1 | awk '{print $3}')"
echo "Root Disk Available: $(df -h / | tail -1 | awk '{print $4}')"
echo ""

# Print network information
echo -e "${YELLOW}=== Network Information ===${NC}"
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I | awk '{print $1}')"
echo "DNS Servers: $(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')"
echo ""

# Print performance settings
echo -e "${YELLOW}=== Performance Settings ===${NC}"
echo "Swappiness: $(cat /proc/sys/vm/swappiness)"
echo "Dirty Ratio: $(cat /proc/sys/vm/dirty_ratio)"
echo "Dirty Background Ratio: $(cat /proc/sys/vm/dirty_background_ratio)"
echo "Dirty Expire Centisecs: $(cat /proc/sys/vm/dirty_expire_centisecs)"
echo "Dirty Writeback Centisecs: $(cat /proc/sys/vm/dirty_writeback_centisecs)"
echo ""

# Print recommendations
echo -e "${YELLOW}=== Recommendations ===${NC}"
if [ $(cat /proc/sys/vm/swappiness) -gt 10 ]; then
    echo -e "${RED}Swappiness is too high. Consider lowering it to 10 or less.${NC}"
else
    echo -e "${GREEN}Swappiness is optimal.${NC}"
fi

if [ $(cat /proc/sys/vm/dirty_ratio) -gt 60 ]; then
    echo -e "${RED}Dirty ratio is too high. Consider lowering it to 60 or less.${NC}"
else
    echo -e "${GREEN}Dirty ratio is optimal.${NC}"
fi

if [ $(cat /proc/sys/vm/dirty_background_ratio) -gt 2 ]; then
    echo -e "${RED}Dirty background ratio is too high. Consider lowering it to 2 or less.${NC}"
else
    echo -e "${GREEN}Dirty background ratio is optimal.${NC}"
fi

if [ $(free -m | grep Mem | awk '{print $7}') -lt 1000 ]; then
    echo -e "${RED}Available memory is low. Consider closing some applications.${NC}"
else
    echo -e "${GREEN}Available memory is sufficient.${NC}"
fi

if [ $(df -h / | tail -1 | awk '{print $5}' | sed 's/%//') -gt 90 ]; then
    echo -e "${RED}Disk usage is high. Consider cleaning up some space.${NC}"
else
    echo -e "${GREEN}Disk usage is optimal.${NC}"
fi
EOF

    sudo chmod +x /usr/local/bin/wsl-performance-monitor
    print_green "✓ Performance monitoring script created"
}

# Function to setup monitoring cron job
setup_monitoring() {
    print_blue "Setting up performance monitoring cron job..."
    (crontab -l 2>/dev/null; echo "*/30 * * * * /usr/local/bin/wsl-performance-monitor") | crontab -
    print_green "✓ Performance monitoring cron job set up"
}

# Function to apply all optimizations
apply_optimizations() {
    print_blue "Applying all optimizations..."
    sudo sysctl -p /etc/sysctl.d/99-wsl-performance.conf
    sudo sysctl -p /etc/sysctl.d/99-wsl-network.conf
    sudo sysctl -p /etc/sysctl.d/99-wsl-io.conf
    print_green "✓ All optimizations applied"
}

# Main function
main() {
    print_blue "Starting WSL performance tuning..."
    
    # Check if running in WSL
    check_wsl
    
    # Backup existing configurations
    backup_configs
    
    # Apply optimizations
    optimize_swap
    optimize_network
    optimize_disk_io
    configure_wsl
    create_monitor_script
    setup_monitoring
    apply_optimizations
    
    print_green "✓ WSL performance tuning completed successfully"
    print_yellow "Note: Some changes may require a WSL restart to take effect"
    print_yellow "Run 'wsl --shutdown' in PowerShell and restart your WSL instance"
}

# Run main function
main 