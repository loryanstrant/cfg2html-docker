#!/bin/bash

set -e

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a /var/log/cfg2html/cron.log
}

log "INFO" "Setting up cron schedule"

# Create cron job for cfg2html user
CRON_USER="cfg2html"

# Write cron job to cfg2html user's crontab
cat << EOF | crontab -u $CRON_USER -
# cfg2html execution schedule
# Run at specified time (default: 2am every Monday)
$CRON_SCHEDULE /app/scripts/run-cfg2html.sh >> /var/log/cfg2html/cron.log 2>&1

# Keep cron logs from growing too large
0 0 * * 0 find /var/log/cfg2html -name "*.log" -mtime +30 -delete

EOF

log "INFO" "Cron schedule configured: $CRON_SCHEDULE"
log "INFO" "Cron job will execute: /app/scripts/run-cfg2html.sh"

# Make sure cron can write to log directory
chown -R cfg2html:cfg2html /var/log/cfg2html
chmod 755 /var/log/cfg2html