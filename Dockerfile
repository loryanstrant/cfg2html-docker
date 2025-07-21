FROM alpine:3.18

# Update package index and install required packages
RUN apk update && apk add --no-cache \
    bash \
    curl \
    openssh-client \
    sshpass \
    dcron \
    tzdata \
    coreutils \
    grep \
    sed \
    gawk \
    gzip \
    tar \
    findutils \
    procps \
    util-linux \
    shadow \
    ca-certificates

# Create user for running the application
RUN addgroup -g 1000 cfg2html && \
    adduser -D -u 1000 -G cfg2html cfg2html

# Download and install cfg2html
RUN curl -L https://github.com/cfg2html/cfg2html/archive/refs/heads/master.tar.gz -o /tmp/cfg2html.tar.gz && \
    tar -xzf /tmp/cfg2html.tar.gz -C /tmp && \
    mv /tmp/cfg2html-master/linux/cfg2html /usr/local/bin/ && \
    chmod +x /usr/local/bin/cfg2html && \
    rm -rf /tmp/cfg2html*

# Create directories
RUN mkdir -p /app/scripts /app/output /var/log/cfg2html /home/cfg2html/.ssh && \
    chown -R cfg2html:cfg2html /app /var/log/cfg2html /home/cfg2html

# Copy scripts
COPY scripts/entrypoint.sh /app/scripts/
COPY scripts/run-cfg2html.sh /app/scripts/
COPY scripts/setup-cron.sh /app/scripts/

# Make scripts executable
RUN chmod +x /app/scripts/*.sh && \
    chown -R cfg2html:cfg2html /app/scripts

# Set up cron
RUN mkdir -p /var/spool/cron/crontabs && \
    touch /var/log/cron.log

# Environment variables with defaults
ENV TZ=UTC
ENV SSH_PORT=22
ENV CRON_SCHEDULE="0 2 * * 1"
ENV RUN_AT_STARTUP=true
ENV OUTPUT_DIR=/app/output
ENV LOG_LEVEL=INFO

# Expose volume for output
VOLUME ["/app/output"]

# Set working directory
WORKDIR /app

# Set entrypoint (will handle user switching internally)
ENTRYPOINT ["/app/scripts/entrypoint.sh"]