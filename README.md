# cfg2html-docker

A Docker solution that executes cfg2html on multiple Linux hosts via SSH, providing automated system configuration documentation and reporting.

[![Docker Build](https://github.com/loryanstrant/cfg2html-docker/actions/workflows/docker-build.yml/badge.svg)](https://github.com/loryanstrant/cfg2html-docker/actions/workflows/docker-build.yml)
[![Docker Image](https://ghcr-badge.egpl.dev/loryanstrant/cfg2html-docker/latest_tag?color=%2344cc11&ignore=latest&label=Docker%20Image&trim=)](https://github.com/loryanstrant/cfg2html-docker/pkgs/container/cfg2html-docker)
[![Security Scan](https://img.shields.io/badge/security-scanned-brightgreen.svg)](https://github.com/loryanstrant/cfg2html-docker/security)
[![Multi-Platform](https://img.shields.io/badge/platform-linux%2Famd64%20%7C%20linux%2Farm64-blue.svg)](https://github.com/loryanstrant/cfg2html-docker/pkgs/container/cfg2html-docker)

## Overview

cfg2html is a UNIX shell script similar to supportinfo, getsysinfo or prtconf on different UNIX platforms. It creates a HTML and plain ASCII host documentation for Linux systems. This Docker container automates the execution of cfg2html across multiple remote hosts via SSH.

## Features

- 🐳 **Containerized**: Runs in Docker with minimal dependencies
- 🔄 **Scheduled Execution**: Configurable cron scheduling (default: 2am every Monday)
- 🚀 **Startup Execution**: Optional immediate execution on container start
- 🔐 **SSH Authentication**: Supports both password and SSH key authentication
- 🌍 **Multi-Host Support**: Process multiple hosts in a single container
- 📁 **File Management**: Automatic versioning with timestamp rotation
- 🕐 **Timezone Support**: Configurable timezone settings
- 📊 **Logging**: Comprehensive logging and error handling
- 🔒 **Security**: Runs as non-root user with configurable permissions
- ⚡ **Auto-Installation**: Automatically installs cfg2html on remote hosts if needed
- 💪 **Multi-Platform**: Supports linux/amd64 and linux/arm64 architectures
- 🛡️ **Security Scanning**: Automated vulnerability scanning with Trivy
- ✅ **Health Monitoring**: Built-in health checks for container monitoring
- 🔧 **CI/CD Ready**: Comprehensive GitHub Actions workflow with automated testing

## Quick Start

### Using Docker Compose (Recommended)

1. **Create docker-compose.yml:**

```yaml
version: '3.8'

services:
  cfg2html:
    image: ghcr.io/loryanstrant/cfg2html-docker:latest
    container_name: cfg2html-docker
    restart: unless-stopped
    
    environment:
      HOSTS: "192.168.1.10:22:root:password,192.168.1.11:22:admin:adminpass"
      TZ: "America/New_York"
      CRON_SCHEDULE: "0 2 * * 1"
      RUN_AT_STARTUP: "true"
    
    volumes:
      - ./output:/app/output
      - ./logs:/var/log/cfg2html
```

2. **Start the container:**

```bash
docker-compose up -d
```

3. **Check the output:**

```bash
ls -la output/
```

### Using Docker Run

```bash
docker run -d \
  --name cfg2html-docker \
  -e HOSTS="192.168.1.10:22:root:password,192.168.1.11:22:admin:adminpass" \
  -e TZ="America/New_York" \
  -v $(pwd)/output:/app/output \
  ghcr.io/loryanstrant/cfg2html-docker:latest
```

## cfg2html Auto-Installation

The container automatically handles cfg2html installation on remote hosts, eliminating the need to pre-install it manually.

### How It Works

When connecting to a remote host, the container will:

1. **Detect Distribution**: Automatically identifies the Linux distribution (Ubuntu/Debian, RHEL/CentOS, Fedora, etc.)
2. **Check Installation**: Verifies if cfg2html is already installed and gets version information
3. **Install if Needed**: Uses the appropriate package manager to install cfg2html:
   - Ubuntu/Debian: `apt-get install cfg2html`
   - RHEL/CentOS: `yum install cfg2html` 
   - Fedora: `dnf install cfg2html`
4. **Fallback Installation**: If package managers fail, downloads and installs from GitHub source
5. **Execute**: Runs cfg2html and collects the system documentation

### Supported Distributions

- ✅ Ubuntu/Debian (using apt)
- ✅ RHEL/CentOS/Rocky/AlmaLinux (using yum)
- ✅ Fedora (using dnf)
- ✅ Generic Linux (manual installation from source)

### Installation Logging

The installation process is fully logged for troubleshooting:

```
[2025-07-25 23:50:01] [INFO] Ensuring cfg2html is installed on 192.168.1.10
[2025-07-25 23:50:01] [INFO] Detecting Linux distribution on 192.168.1.10
[2025-07-25 23:50:02] [INFO] Detected distribution: ubuntu
[2025-07-25 23:50:02] [INFO] Checking cfg2html installation status on 192.168.1.10
[2025-07-25 23:50:03] [INFO] cfg2html not found on 192.168.1.10
[2025-07-25 23:50:03] [INFO] Installing cfg2html on 192.168.1.10 (distro: ubuntu)
[2025-07-25 23:50:04] [INFO] Attempting package installation via apt on 192.168.1.10
[2025-07-25 23:50:15] [INFO] Successfully installed cfg2html via apt on 192.168.1.10
```

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `HOSTS` | Comma-separated list of host configurations | - | ✅ |
| `SSH_PORT` | Default SSH port | `22` | ❌ |
| `SSH_USER` | Default SSH username | - | ❌ |
| `SSH_PASS` | Default SSH password | - | ❌ |
| `TZ` | Timezone setting | `UTC` | ❌ |
| `CRON_SCHEDULE` | Cron schedule expression | `0 2 * * 1` | ❌ |
| `RUN_AT_STARTUP` | Run cfg2html at startup | `true` | ❌ |
| `OUTPUT_DIR` | Output directory path | `/app/output` | ❌ |
| `LOG_LEVEL` | Logging level | `INFO` | ❌ |

### Host Configuration Format

The `HOSTS` environment variable accepts multiple formats:

```bash
# Basic format
HOSTS="hostname1,hostname2,hostname3"

# With custom port
HOSTS="hostname1:2222,hostname2:22"

# With custom user
HOSTS="hostname1:22:admin,hostname2:22:root"

# With password
HOSTS="hostname1:22:admin:password123"

# With SSH key file
HOSTS="hostname1:22:deploy:/app/keys/server_key"

# Mixed configurations
HOSTS="web1.example.com:22:deploy:password123,db1.example.com:2222:postgres:/app/keys/db_key"
```

### SSH Authentication

#### Password Authentication

```yaml
environment:
  HOSTS: "server1:22:root:mypassword,server2:22:admin:adminpass"
```

#### SSH Key Authentication

```yaml
environment:
  HOSTS: "server1:22:deploy:/app/keys/server1_key,server2:22:deploy:/app/keys/server2_key"
volumes:
  - ./ssh-keys:/app/keys:ro
```

### Cron Scheduling

The `CRON_SCHEDULE` variable uses standard cron format:

```bash
# Every Monday at 2am (default)
CRON_SCHEDULE="0 2 * * 1"

# Every day at 3am
CRON_SCHEDULE="0 3 * * *"

# Every Sunday at midnight
CRON_SCHEDULE="0 0 * * 0"

# Every 6 hours
CRON_SCHEDULE="0 */6 * * *"
```

## File Management

### Output Files

Generated reports are stored with timestamped filenames:

```
output/
├── cfg2html_192_168_1_10_20240121_140530.html
├── cfg2html_192_168_1_10_archived_20240121_140530.html
├── cfg2html_192_168_1_11_20240121_140545.html
└── cfg2html_server1_example_com_20240121_140600.html
```

### Automatic Archiving

When a new report is generated for a host, the previous report is automatically renamed with an `_archived_` timestamp to preserve history.

## Advanced Configuration

### Multiple Environments

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  cfg2html-prod:
    image: ghcr.io/loryanstrant/cfg2html-docker:latest
    environment:
      HOSTS: "prod-web1,prod-web2,prod-db1"
      SSH_USER: "deploy"
      SSH_PASS: "${PROD_PASSWORD}"
      TZ: "UTC"
      CRON_SCHEDULE: "0 2 * * 1"
    volumes:
      - ./output/prod:/app/output
      - ./logs/prod:/var/log/cfg2html

  cfg2html-staging:
    image: ghcr.io/loryanstrant/cfg2html-docker:latest
    environment:
      HOSTS: "stage-web1,stage-web2,stage-db1"
      SSH_USER: "deploy" 
      SSH_PASS: "${STAGE_PASSWORD}"
      TZ: "UTC"
      CRON_SCHEDULE: "0 1 * * 1"
    volumes:
      - ./output/staging:/app/output
      - ./logs/staging:/var/log/cfg2html
```

### Security Best Practices

```yaml
services:
  cfg2html:
    image: ghcr.io/loryanstrant/cfg2html-docker:latest
    user: "1000:1000"  # Run as non-root
    read_only: true     # Read-only filesystem
    
    security_opt:
      - no-new-privileges:true
    
    tmpfs:
      - /tmp:noexec,nosuid,size=100m
    
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
```

## Monitoring and Logs

### View Container Logs

```bash
# All logs
docker-compose logs -f

# cfg2html execution logs
docker exec cfg2html-docker tail -f /var/log/cfg2html/cfg2html.log

# Cron logs
docker exec cfg2html-docker tail -f /var/log/cfg2html/cron.log
```

### Health Checks

```bash
# Check container status
docker-compose ps

# Check last execution status
docker exec cfg2html-docker ls -la /app/output/

# Check cron status
docker exec cfg2html-docker ps aux | grep cron
```

## Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   ```bash
   # Check SSH connectivity
   docker exec cfg2html-docker ssh -p 22 user@hostname echo "Connection test"
   ```

2. **Permission Denied**
   ```bash
   # Check file permissions
   docker exec cfg2html-docker ls -la /app/output/
   
   # Fix permissions
   sudo chown -R 1000:1000 output/
   ```

3. **Missing cfg2html Output**
   
   The container now automatically installs cfg2html if it's missing. If you still encounter issues:
   
   ```bash
   # Check the installation logs
   docker exec cfg2html-docker tail -f /var/log/cfg2html/cfg2html.log
   
   # Manually verify cfg2html installation on remote host
   ssh user@hostname "which cfg2html"
   
   # Test manual installation (the container does this automatically now)
   ssh user@hostname "sudo apt-get update && sudo apt-get install -y cfg2html"  # Ubuntu/Debian
   ssh user@hostname "sudo yum install -y cfg2html"      # RHEL/CentOS
   ```

### Debug Mode

Enable debug logging:

```yaml
environment:
  LOG_LEVEL: "DEBUG"
```

### Manual Execution

```bash
# Run cfg2html manually
docker exec cfg2html-docker /app/scripts/run-cfg2html.sh

# Test SSH connection
docker exec -it cfg2html-docker ssh user@hostname
```

## Development and CI/CD

### Automated Workflows

The repository includes comprehensive GitHub Actions workflows for:

- **Build and Push**: Automatically builds multi-platform Docker images and pushes to GHCR
- **Security Scanning**: Uses Trivy for vulnerability scanning
- **Multi-Platform Testing**: Validates images work on both AMD64 and ARM64 architectures
- **Comprehensive Testing**: Runs container functionality tests including health checks

### Manual Workflow Dispatch

You can manually trigger the build workflow:

1. Go to the **Actions** tab in the GitHub repository
2. Select the **Build and Push Docker Image** workflow
3. Click **Run workflow** and choose your environment:
   - `test`: For testing builds
   - `staging`: For staging deployments  
   - `production`: For production releases

### Repository Setup

For detailed setup instructions including GHCR configuration, package visibility settings, and troubleshooting, see the [Setup Guide](docs/SETUP.md).

### Running Tests Locally

```bash
# Run the comprehensive test suite
./test.sh

# Build and test manually
docker build -t cfg2html-docker-local .
docker run --rm -e HOSTS="127.0.0.1" -e RUN_AT_STARTUP="false" cfg2html-docker-local echo "Test passed"
```

## Building from Source

### Prerequisites

- Docker
- Docker Compose

### Build Steps

1. **Clone the repository:**

```bash
git clone https://github.com/loryanstrant/cfg2html-docker.git
cd cfg2html-docker
```

2. **Build the image:**

```bash
docker build -t cfg2html-docker .
```

3. **Run with local image:**

```bash
docker-compose -f docker-compose.yml up -d
```

### Development

```bash
# Build and run for development
docker-compose -f docker-compose.yml -f docker-compose.override.yml up --build

# Run tests
docker build -t test-image .
docker run --rm -e HOSTS="127.0.0.1" -e RUN_AT_STARTUP="false" test-image echo "Test passed"
```

## Examples

See the [examples](examples/) directory for:

- [Configuration Examples](examples/configurations.md)
- [Setup Script](examples/setup.sh)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [cfg2html](https://github.com/cfg2html/cfg2html) - The original cfg2html tool
- [Alpine Linux](https://alpinelinux.org/) - Minimal Docker base image
- [Docker](https://docker.com/) - Containerization platform
