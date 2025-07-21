#!/bin/bash

# Example setup script for cfg2html-docker

set -e

echo "Setting up cfg2html-docker..."

# Create necessary directories
mkdir -p output logs ssh-keys

# Set permissions for SSH keys directory
chmod 700 ssh-keys

# Create example environment file
cat > .env << 'EOF'
# cfg2html Docker Environment Configuration

# Required: Comma-separated list of hosts
# Format: hostname[:port][:username][:password_or_keyfile]
HOSTS=192.168.1.10:22:root:password123,192.168.1.11:22:admin:adminpass

# Optional: Default SSH configuration
SSH_PORT=22
SSH_USER=root
SSH_PASS=defaultpassword

# Optional: Timezone (default: UTC)
TZ=America/New_York

# Optional: Cron schedule (default: 0 2 * * 1 = 2am every Monday)
# Format: minute hour day month weekday
CRON_SCHEDULE=0 2 * * 1

# Optional: Run at startup (default: true)
RUN_AT_STARTUP=true

# Optional: Log level (default: INFO)
LOG_LEVEL=INFO
EOF

# Create example SSH key (for demonstration - replace with real keys)
if [ ! -f ssh-keys/example_key ]; then
    ssh-keygen -t rsa -b 4096 -f ssh-keys/example_key -N "" -C "cfg2html-docker"
    chmod 600 ssh-keys/example_key
    echo "Example SSH key created: ssh-keys/example_key"
    echo "Public key: ssh-keys/example_key.pub"
fi

# Create example docker-compose override
cat > docker-compose.override.yml << 'EOF'
version: '3.8'

services:
  cfg2html:
    # Uncomment to build locally instead of using pre-built image
    # build: .
    
    # Additional environment variables
    environment:
      # Add any additional configuration here
      LOG_LEVEL: "DEBUG"
    
    # Additional volumes for development
    volumes:
      # Uncomment to mount scripts for development
      # - ./scripts:/app/scripts
      pass
EOF

echo "Setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit .env file with your actual host configurations"
echo "2. Place SSH keys in ssh-keys/ directory (if using key authentication)"
echo "3. Review docker-compose.yml configuration"
echo "4. Run: docker-compose up -d"
echo ""
echo "To view logs:"
echo "  docker-compose logs -f"
echo ""
echo "To check output:"
echo "  ls -la output/"