#!/bin/bash

# Script to update YouTube tokens in docker-compose.yml
# Usage: ./update-youtube-tokens.sh "VISITOR_DATA" "PO_TOKEN"

set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <VISITOR_DATA> <PO_TOKEN>"
    echo ""
    echo "Example:"
    echo "  $0 \"CgtHZjFLSHhZcThRTSjnq8G5BjIKCgJDQRIEGgAgOA%3D%3D\" \"MnQBWFhSb85V2g...\""
    echo ""
    echo "See get-youtube-tokens.md for instructions on obtaining these tokens"
    exit 1
fi

VISITOR_DATA="$1"
PO_TOKEN="$2"

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    echo "Error: docker-compose.yml not found in current directory"
    exit 1
fi

# Create backup
BACKUP_FILE="docker-compose.yml.backup.$(date +%Y%m%d_%H%M%S)"
cp docker-compose.yml "$BACKUP_FILE"
echo "✓ Backup created: $BACKUP_FILE"
echo ""

# Update the tokens
echo "Updating YouTube tokens..."

# Read the current file
TEMP_FILE=$(mktemp)

# Process the file
awk -v vd="$VISITOR_DATA" -v pt="$PO_TOKEN" '
# In invidious service section
/^[[:space:]]*# visitor_data and po_token will be handled automatically by Companion/ {
    print "        visitor_data: \"" vd "\""
    print "        po_token: \"" pt "\""
    # Skip the next two comment lines
    getline
    getline
    next
}

# In companion service environment section
/^[[:space:]]*# VISITOR_DATA and PO_TOKEN will be generated automatically/ {
    print "      - VISITOR_DATA=" vd
    print "      - PO_TOKEN=" pt
    # Skip the next two comment lines
    getline
    getline
    next
}

# For any existing visitor_data or po_token lines (not commented)
/^[[:space:]]*visitor_data:/ {
    print "        visitor_data: \"" vd "\""
    next
}
/^[[:space:]]*po_token:/ {
    print "        po_token: \"" pt "\""
    next
}
/^[[:space:]]*- VISITOR_DATA=/ {
    print "      - VISITOR_DATA=" vd
    next
}
/^[[:space:]]*- PO_TOKEN=/ {
    print "      - PO_TOKEN=" pt
    next
}

# Default: print the line as-is
{ print }
' docker-compose.yml > "$TEMP_FILE"

# Replace the original file
mv "$TEMP_FILE" docker-compose.yml

echo "✓ Updated visitor_data in Invidious configuration"
echo "✓ Updated po_token in Invidious configuration"
echo "✓ Updated VISITOR_DATA in Companion service"
echo "✓ Updated PO_TOKEN in Companion service"
echo ""

# Verify the changes
echo "=== Verification ==="
echo "Visitor Data (Invidious):"
grep "visitor_data:" docker-compose.yml | grep -v "^#" || echo "  (commented out)"

echo ""
echo "PO Token (Invidious):"
grep "po_token:" docker-compose.yml | grep -v "^#" || echo "  (commented out)"

echo ""
echo "Visitor Data (Companion):"
grep "VISITOR_DATA=" docker-compose.yml | grep -v "^#" || echo "  (commented out)"

echo ""
echo "PO Token (Companion):"
grep "PO_TOKEN=" docker-compose.yml | grep -v "^#" || echo "  (commented out)"

echo ""
echo "=== Update Complete ==="
echo "✓ Tokens have been updated"
echo "✓ Backup saved as: $BACKUP_FILE"
echo ""
echo "Next steps:"
echo "  1. Restart services: sudo docker-compose down && sudo docker-compose up -d"
echo "  2. Test trending: curl http://localhost:3000/api/v1/trending"
echo "  3. Check browser: http://localhost:3000/feed/trending"
echo ""
echo "Note: Tokens typically expire after 12-24 hours."
echo "      Re-run this script with fresh tokens when they expire."
echo ""
