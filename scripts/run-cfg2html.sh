#!/bin/bash

set -e

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a /var/log/cfg2html/cfg2html.log
}

# Parse host configuration
parse_host_config() {
    local host_config="$1"
    
    # Format: hostname[:port][:username][:password] or hostname[:port][:username][:keyfile]
    IFS=':' read -ra HOST_PARTS <<< "$host_config"
    
    HOST_IP="${HOST_PARTS[0]}"
    HOST_PORT="${HOST_PARTS[1]:-$SSH_PORT}"
    HOST_USER="${HOST_PARTS[2]:-$SSH_USER}"
    HOST_AUTH="${HOST_PARTS[3]:-$SSH_PASS}"
    
    if [ -z "$HOST_IP" ]; then
        log "ERROR" "Invalid host configuration: $host_config"
        return 1
    fi
}

# Detect remote Linux distribution
detect_remote_distro() {
    local ssh_cmd="$1"
    local auth_method="$2"
    local user_host="$3"
    
    log "INFO" "Detecting Linux distribution on $HOST_IP"
    
    # Try to get distribution info
    local distro_info
    if distro_info=$($ssh_cmd $auth_method "$user_host" "cat /etc/os-release 2>/dev/null | grep '^ID=' | cut -d'=' -f2 | tr -d '\"'" 2>/dev/null); then
        echo "$distro_info"
        return 0
    fi
    
    # Fallback: try other methods
    if distro_info=$($ssh_cmd $auth_method "$user_host" "lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]'" 2>/dev/null); then
        echo "$distro_info"
        return 0
    fi
    
    # Last resort: check for package managers
    if $ssh_cmd $auth_method "$user_host" "which apt-get >/dev/null 2>&1" 2>/dev/null; then
        echo "debian"
        return 0
    elif $ssh_cmd $auth_method "$user_host" "which yum >/dev/null 2>&1" 2>/dev/null; then
        echo "rhel"
        return 0
    elif $ssh_cmd $auth_method "$user_host" "which dnf >/dev/null 2>&1" 2>/dev/null; then
        echo "fedora"
        return 0
    fi
    
    log "WARN" "Could not detect distribution on $HOST_IP, assuming generic Linux"
    echo "unknown"
    return 0
}

# Check if cfg2html is installed and get version
check_cfg2html_status() {
    local ssh_cmd="$1"
    local auth_method="$2"
    local user_host="$3"
    
    log "INFO" "Checking cfg2html installation status on $HOST_IP"
    
    # Check if cfg2html is installed
    if ! $ssh_cmd $auth_method "$user_host" "which cfg2html >/dev/null 2>&1" 2>/dev/null; then
        log "INFO" "cfg2html not found on $HOST_IP"
        return 1
    fi
    
    # Get current version
    local current_version
    if current_version=$($ssh_cmd $auth_method "$user_host" "cfg2html -v 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+[^ ]*' | head -1" 2>/dev/null); then
        log "INFO" "Found cfg2html version $current_version on $HOST_IP"
        echo "$current_version"
        return 0
    fi
    
    log "INFO" "cfg2html found but version could not be determined on $HOST_IP"
    echo "unknown"
    return 0
}

# Get latest cfg2html version from GitHub
get_latest_cfg2html_version() {
    log "INFO" "Checking for latest cfg2html version"
    
    # Try to get latest version from GitHub API
    local latest_version
    if command -v curl >/dev/null 2>&1; then
        latest_version=$(curl -s https://api.github.com/repos/cfg2html/cfg2html/releases/latest | grep '"tag_name"' | cut -d'"' -f4 2>/dev/null)
    elif command -v wget >/dev/null 2>&1; then
        latest_version=$(wget -qO- https://api.github.com/repos/cfg2html/cfg2html/releases/latest | grep '"tag_name"' | cut -d'"' -f4 2>/dev/null)
    fi
    
    if [ -n "$latest_version" ] && [ "$latest_version" != "null" ]; then
        log "INFO" "Latest cfg2html version: $latest_version"
        echo "$latest_version"
        return 0
    fi
    
    # Fallback: assume we need to install/update
    log "WARN" "Could not determine latest cfg2html version, will install from master branch"
    echo "master"
    return 0
}

# Install cfg2html on remote system
install_cfg2html() {
    local ssh_cmd="$1"
    local auth_method="$2"
    local user_host="$3"
    local distro="$4"
    
    log "INFO" "Installing cfg2html on $HOST_IP (distro: $distro)"
    
    # First try package manager installation
    case "$distro" in
        ubuntu|debian)
            log "INFO" "Attempting package installation via apt on $HOST_IP"
            if $ssh_cmd $auth_method "$user_host" "sudo apt-get update && sudo apt-get install -y cfg2html" 2>/dev/null; then
                log "INFO" "Successfully installed cfg2html via apt on $HOST_IP"
                return 0
            fi
            log "WARN" "Package installation failed, trying manual installation on $HOST_IP"
            ;;
        rhel|centos|rocky|almalinux)
            log "INFO" "Attempting package installation via yum on $HOST_IP"
            if $ssh_cmd $auth_method "$user_host" "sudo yum update -y && sudo yum install -y cfg2html" 2>/dev/null; then
                log "INFO" "Successfully installed cfg2html via yum on $HOST_IP"
                return 0
            fi
            log "WARN" "Package installation failed, trying manual installation on $HOST_IP"
            ;;
        fedora)
            log "INFO" "Attempting package installation via dnf on $HOST_IP"
            if $ssh_cmd $auth_method "$user_host" "sudo dnf update -y && sudo dnf install -y cfg2html" 2>/dev/null; then
                log "INFO" "Successfully installed cfg2html via dnf on $HOST_IP"
                return 0
            fi
            log "WARN" "Package installation failed, trying manual installation on $HOST_IP"
            ;;
    esac
    
    # Manual installation from GitHub
    log "INFO" "Attempting manual installation from GitHub on $HOST_IP"
    local install_script='
        set -e
        cd /tmp
        wget --no-check-certificate https://github.com/cfg2html/cfg2html/archive/refs/heads/master.tar.gz -O cfg2html.tar.gz 2>/dev/null || curl -L https://github.com/cfg2html/cfg2html/archive/refs/heads/master.tar.gz -o cfg2html.tar.gz 2>/dev/null
        tar -xzf cfg2html.tar.gz
        cd cfg2html-master
        find . -name "cfg2html" -type f -executable | head -1 | xargs -I {} sudo cp {} /usr/local/bin/cfg2html
        sudo chmod +x /usr/local/bin/cfg2html
        cd /tmp
        rm -rf cfg2html*
        echo "cfg2html manual installation completed"
    '
    
    if $ssh_cmd $auth_method "$user_host" "$install_script" 2>/dev/null; then
        log "INFO" "Successfully installed cfg2html manually on $HOST_IP"
        return 0
    fi
    
    log "ERROR" "Failed to install cfg2html on $HOST_IP"
    return 1
}

# Ensure cfg2html is installed and up to date
ensure_cfg2html_installed() {
    local ssh_cmd="$1"
    local auth_method="$2"
    local user_host="$3"
    
    # Detect distribution
    local distro
    distro=$(detect_remote_distro "$ssh_cmd" "$auth_method" "$user_host")
    
    # Check current installation status
    local current_version
    if current_version=$(check_cfg2html_status "$ssh_cmd" "$auth_method" "$user_host"); then
        if [ "$current_version" = "" ]; then
            # Not installed
            log "INFO" "cfg2html not installed on $HOST_IP, installing..."
            install_cfg2html "$ssh_cmd" "$auth_method" "$user_host" "$distro"
            return $?
        else
            # Already installed - for now, we'll assume it's good enough
            # In future versions, we could add version comparison logic
            log "INFO" "cfg2html already installed on $HOST_IP (version: $current_version)"
            return 0
        fi
    else
        # Not installed
        log "INFO" "cfg2html not installed on $HOST_IP, installing..."
        install_cfg2html "$ssh_cmd" "$auth_method" "$user_host" "$distro"
        return $?
    fi
}

# Execute cfg2html on remote host
execute_cfg2html() {
    local host_config="$1"
    
    parse_host_config "$host_config"
    
    log "INFO" "Processing host: $HOST_IP:$HOST_PORT (user: $HOST_USER)"
    
    # Create SSH command
    local ssh_cmd="ssh -p $HOST_PORT"
    local auth_method=""
    
    # Determine authentication method
    if [ -f "$HOST_AUTH" ]; then
        # SSH key file
        auth_method="-i $HOST_AUTH"
        log "INFO" "Using SSH key authentication for $HOST_IP"
    else
        # Password authentication using sshpass
        if command -v sshpass >/dev/null 2>&1; then
            ssh_cmd="sshpass -p '$HOST_AUTH' $ssh_cmd"
            log "INFO" "Using password authentication for $HOST_IP"
        else
            log "ERROR" "sshpass not available for password authentication"
            return 1
        fi
    fi
    
    # Create timestamped filename
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local hostname_clean=$(echo "$HOST_IP" | tr '.' '_')
    local output_file="$OUTPUT_DIR/cfg2html_${hostname_clean}_${timestamp}.html"
    local temp_output="/tmp/cfg2html_${hostname_clean}_${timestamp}.html"
    
    # Archive previous output if it exists
    local existing_file=$(find "$OUTPUT_DIR" -name "cfg2html_${hostname_clean}_*.html" -not -name "*_archived_*" | head -1)
    if [ -n "$existing_file" ] && [ -f "$existing_file" ]; then
        local archive_name="${existing_file%.*}_archived_${timestamp}.html"
        log "INFO" "Archiving previous output: $(basename "$existing_file") -> $(basename "$archive_name")"
        mv "$existing_file" "$archive_name"
    fi
    
    # Ensure cfg2html is installed before execution
    log "INFO" "Ensuring cfg2html is installed on $HOST_IP"
    if ! ensure_cfg2html_installed "$ssh_cmd" "$auth_method" "$HOST_USER@$HOST_IP"; then
        log "ERROR" "Failed to ensure cfg2html installation on $HOST_IP"
        rm -f "$temp_output"
        return 1
    fi
    
    log "INFO" "Executing cfg2html on $HOST_IP"
    
    # Execute cfg2html remotely and capture output
    if $ssh_cmd $auth_method "$HOST_USER@$HOST_IP" "sudo cfg2html -o -" > "$temp_output" 2>/dev/null; then
        # Move temp file to final location
        mv "$temp_output" "$output_file"
        log "INFO" "Successfully generated cfg2html report for $HOST_IP: $(basename "$output_file")"
        
        # Log file size
        local file_size=$(du -h "$output_file" | cut -f1)
        log "INFO" "Report size: $file_size"
        
        return 0
    else
        log "ERROR" "Failed to execute cfg2html on $HOST_IP"
        rm -f "$temp_output"
        return 1
    fi
}

# Main execution
main() {
    log "INFO" "Starting cfg2html execution run"
    
    # Validate environment
    if [ -z "$HOSTS" ]; then
        log "ERROR" "HOSTS environment variable not set"
        exit 1
    fi
    
    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    
    # Process each host
    IFS=',' read -ra HOST_LIST <<< "$HOSTS"
    local success_count=0
    local total_count=${#HOST_LIST[@]}
    
    for host_config in "${HOST_LIST[@]}"; do
        # Trim whitespace
        host_config=$(echo "$host_config" | xargs)
        
        if [ -n "$host_config" ]; then
            if execute_cfg2html "$host_config"; then
                ((success_count++))
            fi
        fi
    done
    
    log "INFO" "cfg2html execution completed: $success_count/$total_count hosts successful"
    
    if [ $success_count -eq 0 ]; then
        log "ERROR" "No hosts processed successfully"
        exit 1
    fi
}

# Run main function only if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi