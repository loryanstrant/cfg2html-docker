#!/bin/bash

# Test script for cfg2html-docker

set -e

# Cleanup function
cleanup() {
    local exit_code=$?
    echo ""
    echo "Cleaning up test resources..."
    
    # Stop and remove any test containers that might be running
    docker ps -q --filter="ancestor=cfg2html-docker-test" | xargs -r docker stop || true
    docker ps -aq --filter="ancestor=cfg2html-docker-test" | xargs -r docker rm || true
    
    # Remove test image if cleanup is requested
    if [ "${CLEANUP_IMAGE:-false}" = "true" ]; then
        docker rmi cfg2html-docker-test || true
    fi
    
    if [ $exit_code -ne 0 ]; then
        echo "❌ Tests failed with exit code $exit_code"
    fi
    
    exit $exit_code
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

echo "Testing cfg2html-docker build and functionality..."

# Build the Docker image
echo "Building Docker image..."
docker build -t cfg2html-docker-test .

# Test 1: Container starts and validates environment
echo "Test 1: Environment validation test..."
echo "  - Testing missing HOSTS variable..."
if docker run --rm cfg2html-docker-test timeout 5 /app/scripts/entrypoint.sh 2>&1 | grep -q "HOSTS environment variable is required"; then
    echo "  ✅ Missing HOSTS validation works"
else
    echo "  ❌ Missing HOSTS validation failed"
    echo "  Container output:"
    docker run --rm cfg2html-docker-test timeout 5 /app/scripts/entrypoint.sh 2>&1 | head -10
    exit 1
fi

echo "  - Testing valid HOSTS variable..."
if docker run --rm -e HOSTS="dummy:22:user:pass" cfg2html-docker-test timeout 10 /app/scripts/entrypoint.sh 2>&1 | grep -q "Starting cfg2html-docker container"; then
    echo "  ✅ Valid HOSTS validation works"
else
    echo "  ❌ Valid HOSTS validation failed"
    echo "  Container output:"
    docker run --rm -e HOSTS="dummy:22:user:pass" cfg2html-docker-test timeout 10 /app/scripts/entrypoint.sh 2>&1 | head -10
    exit 1
fi
echo "✅ Environment validation test passed"

# Test 2: Check if cfg2html is installed
echo "Test 2: cfg2html installation test..."
if docker run --rm --entrypoint="" cfg2html-docker-test which cfg2html > /dev/null 2>&1; then
    echo "✅ cfg2html is installed"
else
    echo "❌ cfg2html not found"
    echo "Container output:"
    docker run --rm --entrypoint="" cfg2html-docker-test which cfg2html 2>&1
    exit 1
fi

# Test 3: Check if required tools are available
echo "Test 3: Required tools test..."
tools_missing=0
for tool in ssh sshpass cron su; do
    if ! docker run --rm --entrypoint="" cfg2html-docker-test which $tool > /dev/null 2>&1; then
        echo "❌ $tool not found"
        echo "Container output for $tool:"
        docker run --rm --entrypoint="" cfg2html-docker-test which $tool 2>&1
        tools_missing=1
    fi
done

if [ $tools_missing -eq 0 ]; then
    echo "✅ All required tools are available"
else
    echo "❌ Some required tools are missing"
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
        echo "Container output for $script permissions:"
        docker run --rm --entrypoint="" cfg2html-docker-test ls -la /app/scripts/$script 2>&1
    fi
done

if [ $scripts_ok -eq 3 ]; then
    echo "✅ All scripts have proper permissions"
else
    echo "❌ Some scripts don't have proper permissions"
    exit 1
fi

# Test 5: Container lifecycle with HOSTS environment
echo "Test 5: Container lifecycle test..."
echo "  - Testing container startup with HOSTS..."
container_id=$(docker run -d -e HOSTS="dummy:22:user:pass" -e RUN_AT_STARTUP="false" cfg2html-docker-test)
if [ $? -eq 0 ]; then
    echo "  ✅ Container started successfully"
    
    # Wait a moment for container to initialize
    sleep 5
    
    # Check container logs for proper initialization
    container_logs=$(docker logs "$container_id" 2>&1)
    if echo "$container_logs" | grep -q "Container started successfully"; then
        echo "  ✅ Container initialized properly"
    else
        echo "  ❌ Container initialization failed"
        echo "  Container logs:"
        echo "$container_logs" | head -10
        docker stop "$container_id" > /dev/null 2>&1 || true
        docker rm "$container_id" > /dev/null 2>&1 || true
        exit 1
    fi
    
    # Check if the entrypoint script ran without errors
    if echo "$container_logs" | grep -q "ERROR"; then
        echo "  ❌ Container has errors in logs"
        echo "  Container logs:"
        echo "$container_logs"
        docker stop "$container_id" > /dev/null 2>&1 || true
        docker rm "$container_id" > /dev/null 2>&1 || true
        exit 1
    else
        echo "  ✅ Container running without errors"
    fi
    
    # Clean up test container
    docker stop "$container_id" > /dev/null 2>&1 || true
    docker rm "$container_id" > /dev/null 2>&1 || true
else
    echo "  ❌ Failed to start container"
    exit 1
fi
echo "✅ Container lifecycle test passed"

echo ""
echo "🎉 All tests passed! cfg2html-docker is ready for use."
echo ""
echo "To run the container:"
echo "docker run -d -e HOSTS='your.server.com:22:user:password' -v ./output:/app/output cfg2html-docker-test"