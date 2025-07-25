FROM ubuntu:22.04

# Set environment to avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Update package list and install required packages
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    openssh-client \
    sshpass \
    cron \
    tzdata \
    gzip \
    tar \
    findutils \
    procps \
    sudo \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create user for running the application
RUN groupadd -g 1000 cfg2html && \
    useradd -d /home/cfg2html -s /bin/bash -u 1000 -g 1000 cfg2html

# Download and install cfg2html
RUN wget --no-check-certificate https://github.com/cfg2html/cfg2html/archive/refs/heads/master.tar.gz -O /tmp/cfg2html.tar.gz && \
    tar -xzf /tmp/cfg2html.tar.gz -C /tmp && \
    find /tmp/cfg2html-master -name "cfg2html" -type f -exec cp {} /usr/local/bin/ \; && \
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