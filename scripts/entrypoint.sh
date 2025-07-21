#!/bin/bash

set -e

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a /var/log/cfg2html/entrypoint.log
}

log "INFO" "Starting cfg2html-docker container"

# Validate required environment variables
if [ -z "$HOSTS" ]; then
    log "ERROR" "HOSTS environment variable is required"
    exit 1
fi

# Set timezone
if [ -n "$TZ" ]; then
    log "INFO" "Setting timezone to $TZ"
    if [ "$(id -u)" = "0" ]; then
        ln -sf /usr/share/zoneinfo/$TZ /etc/localtime
        echo $TZ > /etc/timezone
    else
        log "WARN" "Cannot set timezone as non-root user"
    fi
fi

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Setup cron if running as root
if [ "$(id -u)" = "0" ]; then
    log "INFO" "Running as root, setting up cron service"
    /app/scripts/setup-cron.sh
    
    # Start cron daemon
    log "INFO" "Starting cron daemon"
    service cron start
    
    # Switch to cfg2html user for SSH operations
    log "INFO" "Switching to cfg2html user for SSH operations"
    export USER_ID=$(id -u cfg2html)
    export GROUP_ID=$(id -g cfg2html)
else
    log "INFO" "Running as non-root user"
    USER_ID=$(id -u)
    GROUP_ID=$(id -g)
fi

# Set up SSH client configuration
log "INFO" "Setting up SSH client configuration"
SSH_HOME="/home/cfg2html"
if [ "$(id -u)" != "0" ]; then
    SSH_HOME="$HOME"
fi

mkdir -p "$SSH_HOME/.ssh"
chmod 700 "$SSH_HOME/.ssh"

# Create SSH config with secure defaults
cat > "$SSH_HOME/.ssh/config" << EOF
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
    ConnectTimeout 30
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF
chmod 600 "$SSH_HOME/.ssh/config"

# Run cfg2html at startup if enabled
if [ "$RUN_AT_STARTUP" = "true" ]; then
    log "INFO" "Running cfg2html at startup"
    if [ "$(id -u)" = "0" ]; then
        # Run as cfg2html user
        su -c "/app/scripts/run-cfg2html.sh" cfg2html
    else
        /app/scripts/run-cfg2html.sh
    fi
fi

# Keep container running
log "INFO" "Container started successfully, keeping alive"
# Keep the container running by tailing logs or sleeping
if [ -f /var/log/cfg2html/cfg2html.log ]; then
    tail -f /var/log/cfg2html/*.log
else
    # Create initial log file and tail it
    touch /var/log/cfg2html/container.log
    echo "Container is running and waiting for scheduled jobs..." > /var/log/cfg2html/container.log
    tail -f /var/log/cfg2html/container.log &
    
    # Keep checking for cron process
    while true; do
        if pgrep cron > /dev/null; then
            sleep 60
        else
            log "WARN" "Cron process not found, restarting..."
            service cron start
            sleep 10
        fi
    done
fi