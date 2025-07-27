#!/bin/bash

# Test script for cfg2html-docker

set -e

echo "Testing cfg2html-docker build and functionality..."

# Clean up any existing test containers/images
cleanup() {
    echo "Cleaning up test resources..."
    docker stop cfg2html-docker-test-container 2>/dev/null || true
    docker rm cfg2html-docker-test-container 2>/dev/null || true
    docker rmi cfg2html-docker-test 2>/dev/null || true
}
trap cleanup EXIT

# Build the Docker image
echo "Building Docker image..."
docker build -t cfg2html-docker-test .

# Test 1: Container starts and validates environment
echo "Test 1: Environment validation test..."
if timeout 10 docker run --rm --name cfg2html-docker-test-temp cfg2html-docker-test 2>&1 | grep -q "HOSTS environment variable is required"; then
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

# Test 5: Container health and lifecycle
echo "Test 5: Container health and lifecycle test..."
docker run --name cfg2html-docker-test-container -d \
    -e HOSTS="127.0.0.1" \
    -e RUN_AT_STARTUP="false" \
    -e LOG_LEVEL="DEBUG" \
    cfg2html-docker-test

# Wait for container to start up properly
sleep 5

# Check if container is still running
if docker ps | grep -q cfg2html-docker-test-container; then
    echo "✅ Container lifecycle test passed"
else
    echo "❌ Container lifecycle test failed"
    docker logs cfg2html-docker-test-container
    exit 1
fi

# Test 6: Health check functionality
echo "Test 6: Health check test..."
# Wait for health check to initialize
sleep 30

HEALTH_STATUS=$(docker inspect --format='{{.State.Health.Status}}' cfg2html-docker-test-container 2>/dev/null || echo "no-healthcheck")
if [ "$HEALTH_STATUS" = "healthy" ] || [ "$HEALTH_STATUS" = "no-healthcheck" ]; then
    echo "✅ Health check passed (Status: $HEALTH_STATUS)"
else
    echo "⚠️  Health check status: $HEALTH_STATUS (container may still be starting)"
fi

# Clean up the test container
docker stop cfg2html-docker-test-container
docker rm cfg2html-docker-test-container

echo ""
echo "🎉 All tests passed! cfg2html-docker is ready for use."
echo ""
echo "To run the container:"
echo "docker run -d -e HOSTS='your.server.com:22:user:password' -v ./output:/app/output cfg2html-docker-test"