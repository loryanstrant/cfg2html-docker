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

# Run main function
main "$@"