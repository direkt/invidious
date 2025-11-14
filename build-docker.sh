#!/bin/bash
# Build script for Invidious Docker image

echo "Building Invidious Docker image with your changes..."
echo "This will run tests automatically during the build process."
echo ""

docker-compose build

if [ $? -eq 0 ]; then
    echo ""
    echo "✓ Build successful! Tests passed."
    echo ""
    echo "To start Invidious, run:"
    echo "  docker-compose up -d"
    echo ""
    echo "To view logs:"
    echo "  docker-compose logs -f invidious"
else
    echo ""
    echo "✗ Build failed. Check the output above for errors."
    exit 1
fi
