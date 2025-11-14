#!/bin/bash
# Setup and build script for Invidious with your changes

set -e

echo "=========================================="
echo "Invidious Docker Setup and Build"
echo "=========================================="
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    echo "This script needs to run with sudo for Docker access."
    echo "Please run: sudo ./setup-and-build.sh"
    exit 1
fi

echo "Step 1: Building Docker image (this will run tests automatically)..."
echo "This may take several minutes..."
echo ""

docker-compose build

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "✓ Build successful! Tests passed."
    echo "=========================================="
    echo ""
    echo "Step 2: Starting Invidious services..."
    echo ""

    docker-compose up -d

    echo ""
    echo "=========================================="
    echo "✓ Invidious is starting up!"
    echo "=========================================="
    echo ""
    echo "Services status:"
    docker-compose ps
    echo ""
    echo "Waiting for services to be healthy (this may take 30-60 seconds)..."
    sleep 10
    echo ""
    echo "To view logs:"
    echo "  sudo docker-compose logs -f invidious"
    echo ""
    echo "To check status:"
    echo "  sudo docker-compose ps"
    echo ""
    echo "To stop:"
    echo "  sudo docker-compose down"
    echo ""
    echo "Once healthy, access Invidious at:"
    echo "  http://127.0.0.1:3000"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "✗ Build failed. Check the output above."
    echo "=========================================="
    exit 1
fi
