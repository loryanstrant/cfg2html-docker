#!/bin/bash

set -e

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a /var/log/cfg2html/cron.log
}

log "INFO" "Setting up cron schedule"

# Create cron job
CRON_USER="cfg2html"
CRON_FILE="/var/spool/cron/crontabs/$CRON_USER"

# Ensure cron directory exists
mkdir -p /var/spool/cron/crontabs

# Create cron job content
cat > "$CRON_FILE" << EOF
# cfg2html execution schedule
# Run at specified time (default: 2am every Monday)
$CRON_SCHEDULE /app/scripts/run-cfg2html.sh >> /var/log/cfg2html/cron.log 2>&1

# Keep cron logs from growing too large
0 0 * * 0 find /var/log/cfg2html -name "*.log" -mtime +30 -delete

EOF

# Set proper permissions
chmod 600 "$CRON_FILE"
if command -v chown >/dev/null 2>&1; then
    chown "$CRON_USER:$CRON_USER" "$CRON_FILE" 2>/dev/null || true
fi

log "INFO" "Cron schedule configured: $CRON_SCHEDULE"
log "INFO" "Cron job will execute: /app/scripts/run-cfg2html.sh"