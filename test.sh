#!/bin/bash

# Test script for cfg2html-docker

set -e

echo "Testing cfg2html-docker build and functionality..."

# Build the Docker image
echo "Building Docker image..."
docker build -t cfg2html-docker-test .

# Test 1: Container starts and validates environment
echo "Test 1: Environment validation test..."
if docker run --rm cfg2html-docker-test timeout 5 /app/scripts/entrypoint.sh 2>&1 | grep -q "HOSTS environment variable is required"; then
    echo "✅ Environment validation works"
else
    echo "❌ Environment validation failed"
    exit 1
fi

# Test 2: Check if cfg2html is installed
echo "Test 2: cfg2html installation test..."
if docker run --rm --entrypoint="" cfg2html-docker-test which cfg2html > /dev/null; then
    echo "✅ cfg2html is installed"
else
    echo "❌ cfg2html not found"
    exit 1
fi

# Test 3: Check if required tools are available
echo "Test 3: Required tools test..."
tools_missing=0
for tool in ssh sshpass cron su; do
    if ! docker run --rm --entrypoint="" cfg2html-docker-test which $tool > /dev/null 2>&1; then
        echo "❌ $tool not found"
        tools_missing=1
    fi
done

if [ $tools_missing -eq 0 ]; then
    echo "✅ All required tools are available"
else
    exit 1
fi

# Test 4: Script permissions
echo "Test 4: Script permissions test..."
scripts_ok=0
for script in entrypoint.sh run-cfg2html.sh setup-cron.sh; do
    if docker run --rm --entrypoint="" cfg2html-docker-test test -x /app/scripts/$script; then
        scripts_ok=$((scripts_ok + 1))
    else
        echo "❌ $script is not executable"
    fi
done

if [ $scripts_ok -eq 3 ]; then
    echo "✅ All scripts have proper permissions"
else
    exit 1
fi

# Test 5: Container lifecycle test
echo "Test 5: Container lifecycle test..."
container_name="cfg2html-lifecycle-test"

# Clean up any existing container
docker rm -f $container_name >/dev/null 2>&1 || true

# Run container in detached mode with required HOSTS environment variable
if docker run -d --name $container_name -e HOSTS="dummy:22:user:pass" -e RUN_AT_STARTUP="false" cfg2html-docker-test; then
    echo "✅ Container started in detached mode"
    
    # Wait a moment for container to initialize
    sleep 2
    
    # Check if container is still running
    if docker ps | grep $container_name > /dev/null; then
        echo "✅ Container is running and healthy"
        
        # Test that we can execute commands in the running container
        if docker exec $container_name echo "Health check successful" > /dev/null 2>&1; then
            echo "✅ Container is responsive to commands"
        else
            echo "❌ Container is not responsive to commands"
            echo "Container logs:"
            docker logs $container_name
            docker rm -f $container_name >/dev/null 2>&1
            exit 1
        fi
    else
        echo "❌ Container stopped unexpectedly"
        echo "Container logs:"
        docker logs $container_name
        docker rm -f $container_name >/dev/null 2>&1
        exit 1
    fi
    
    # Clean up
    docker rm -f $container_name >/dev/null 2>&1
else
    echo "❌ Failed to start container in detached mode"
    echo "Container logs:"
    docker logs $container_name 2>/dev/null || echo "No logs available"
    docker rm -f $container_name >/dev/null 2>&1
    exit 1
fi

# Test 6: Container health check without startup run
echo "Test 6: Container health check (no startup run)..."
container_name="cfg2html-health-test"

# Clean up any existing container
docker rm -f $container_name >/dev/null 2>&1 || true

# Run container with startup disabled to test pure health
if docker run -d --name $container_name -e HOSTS="test.example.com:22:testuser:testpass" -e RUN_AT_STARTUP="false" cfg2html-docker-test; then
    # Wait for container to stabilize
    sleep 3
    
    # Verify container is running
    if docker ps --filter "name=$container_name" --filter "status=running" | grep $container_name > /dev/null; then
        echo "✅ Container health check passed"
    else
        echo "❌ Container health check failed - container not running"
        echo "Container status:"
        docker ps -a --filter "name=$container_name"
        echo "Container logs:"
        docker logs $container_name
        docker rm -f $container_name >/dev/null 2>&1
        exit 1
    fi
    
    # Clean up
    docker rm -f $container_name >/dev/null 2>&1
else
    echo "❌ Failed to start container for health check"
    echo "Container logs:"
    docker logs $container_name 2>/dev/null || echo "No logs available"
    docker rm -f $container_name >/dev/null 2>&1
    exit 1
fi

echo ""
echo "🎉 All tests passed! cfg2html-docker is ready for use."
echo ""
echo "To run the container:"
echo "docker run -d -e HOSTS='your.server.com:22:user:password' -v ./output:/app/output cfg2html-docker-test"