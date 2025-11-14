#!/bin/bash

# Automated key generation and setup for Invidious Docker installation
# This script generates secure keys using pwgen and updates docker-compose.yml

set -e

echo "=== Invidious Docker Key Setup Automation ==="
echo ""

# Check if pwgen is installed
if ! command -v pwgen &> /dev/null; then
    echo "Error: pwgen is not installed."
    echo "Install it with: sudo apt-get install pwgen (Debian/Ubuntu)"
    echo "                 sudo yum install pwgen (RHEL/CentOS)"
    echo "                 brew install pwgen (macOS)"
    exit 1
fi

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found in current directory"
    exit 1
fi

# Create backup of docker-compose.yml
BACKUP_FILE="docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)"
cp docker-compose.yml "$BACKUP_FILE"
echo "✓ Backup created: $BACKUP_FILE"
echo ""

# Generate keys
echo "Generating secure keys..."
HMAC_KEY=$(pwgen -s 20 1)
COMPANION_KEY=$(pwgen -s 16 1)

echo "✓ Generated HMAC_KEY: $HMAC_KEY (20 characters)"
echo "✓ Generated COMPANION_KEY: $COMPANION_KEY (16 characters)"
echo ""

# Update docker-compose.yml
echo "Updating docker-compose.yml..."

# Use sed to replace the keys
# For hmac_key (line ~35)
sed -i.tmp "s/hmac_key: \"[^\"]*\"/hmac_key: \"$HMAC_KEY\"/g" docker-compose.yml

# For invidious_companion_key (line ~36)
sed -i.tmp "s/invidious_companion_key: \"[^\"]*\"/invidious_companion_key: \"$COMPANION_KEY\"/g" docker-compose.yml

# For SERVER_SECRET_KEY in companion service (line ~51)
sed -i.tmp "s/SERVER_SECRET_KEY=.*/SERVER_SECRET_KEY=$COMPANION_KEY/g" docker-compose.yml

# Remove temporary file created by sed
rm -f docker-compose.yml.tmp

echo "✓ Updated hmac_key in Invidious configuration"
echo "✓ Updated invidious_companion_key in Invidious configuration"
echo "✓ Updated SERVER_SECRET_KEY in Companion service"
echo ""

# Verify the changes
echo "=== Verification ==="
echo "HMAC Key:"
grep "hmac_key:" docker-compose.yml | head -1

echo ""
echo "Companion Key (Invidious config):"
grep "invidious_companion_key:" docker-compose.yml | head -1

echo ""
echo "Companion Key (Companion service):"
grep "SERVER_SECRET_KEY=" docker-compose.yml | head -1

echo ""
echo "=== Setup Complete ==="
echo "✓ Keys have been generated and configured"
echo "✓ Backup saved as: $BACKUP_FILE"
echo ""
echo "IMPORTANT SECURITY NOTES:"
echo "  - These keys are unique to this instance"
echo "  - Do NOT share these keys publicly"
echo "  - Do NOT commit them to version control"
echo "  - Keep the backup file in a secure location"
echo ""
echo "Next steps:"
echo "  1. Review the changes: diff docker-compose.yml $BACKUP_FILE"
echo "  2. Start your services: docker-compose up -d"
echo "  3. Check logs: docker-compose logs -f"
echo ""
