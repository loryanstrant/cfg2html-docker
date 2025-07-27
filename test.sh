#!/bin/bash

# Test script for cfg2html-docker

set -e

echo "Testing cfg2html-docker build and functionality..."

# Build the Docker image
echo "Building Docker image..."
docker build -t cfg2html-docker-test .

# Test 1: Negative test - Container should fail without HOSTS
echo "Test 1: Environment validation test (negative case)..."
if timeout 10 docker run --rm cfg2html-docker-test 2>&1 | grep -q "HOSTS environment variable is required"; then
    echo "✅ Environment validation works - container fails when HOSTS is missing"
else
    echo "❌ Environment validation failed - container should fail when HOSTS is missing"
    echo "Container output:"
    timeout 10 docker run --rm cfg2html-docker-test 2>&1 | head -10
    exit 1
fi

# Test 1b: Positive test - Container should start successfully with HOSTS
echo "Test 1b: Environment validation test (positive case)..."
CONTAINER_ID=$(docker run -d -e HOSTS="dummy:22:user:pass" -e RUN_AT_STARTUP="false" cfg2html-docker-test)
sleep 5

# Check if container is still running (it should be)
if docker ps -q --filter "id=$CONTAINER_ID" | grep -q .; then
    echo "✅ Container starts successfully when HOSTS is provided"
    # Cleanup
    docker stop $CONTAINER_ID >/dev/null 2>&1
    docker rm $CONTAINER_ID >/dev/null 2>&1
else
    echo "❌ Container failed to start when HOSTS is provided"
    echo "Container logs:"
    docker logs $CONTAINER_ID 2>&1
    # Cleanup
    docker rm $CONTAINER_ID >/dev/null 2>&1 || true
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

echo ""
echo "🎉 All tests passed! cfg2html-docker is ready for use."
echo ""
echo "To run the container:"
echo "docker run -d -e HOSTS='your.server.com:22:user:password' -v ./output:/app/output cfg2html-docker-test"

# Cleanup test image
echo ""
echo "Cleaning up test image..."
docker rmi cfg2html-docker-test >/dev/null 2>&1 || true
echo "✅ Cleanup completed"