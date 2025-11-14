#!/bin/bash
# Setup automatic token rotation using cron

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROTATE_SCRIPT="$SCRIPT_DIR/rotate-tokens.sh"
CRON_JOB="0 */6 * * * cd $SCRIPT_DIR && $ROTATE_SCRIPT >> $SCRIPT_DIR/token-rotation-cron.log 2>&1"

echo "=========================================="
echo "   Auto-Rotation Setup Script"
echo "=========================================="
echo ""

# Check if script exists
if [ ! -f "$ROTATE_SCRIPT" ]; then
    echo "ERROR: rotate-tokens.sh not found at $ROTATE_SCRIPT"
    exit 1
fi

# Make script executable
chmod +x "$ROTATE_SCRIPT"

echo "This will set up automatic token rotation every 6 hours."
echo "Cron job: $CRON_JOB"
echo ""
read -p "Do you want to continue? (y/N): " -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Check if cron job already exists
if crontab -l 2>/dev/null | grep -q "$ROTATE_SCRIPT"; then
    echo "Cron job already exists. Removing old entry..."
    crontab -l | grep -v "$ROTATE_SCRIPT" | crontab -
fi

# Add cron job
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo ""
echo "✓ Cron job added successfully!"
echo ""
echo "Current crontab:"
crontab -l
echo ""
echo "Automatic rotation will run every 6 hours."
echo "Log file: $SCRIPT_DIR/token-rotation-cron.log"
echo ""
echo "To remove auto-rotation, run:"
echo "  crontab -e"
echo "  # Then delete the line containing: $ROTATE_SCRIPT"
echo ""
echo "To run manually at any time:"
echo "  cd $SCRIPT_DIR && ./rotate-tokens.sh"
echo ""
