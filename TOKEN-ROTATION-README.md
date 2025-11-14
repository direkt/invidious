# YouTube Token Rotation for Invidious

This directory contains scripts to automatically rotate YouTube tokens (`visitor_data` and `po_token`) for your Invidious instance.

## Problem

YouTube requires valid `visitor_data` and `po_token` to access their InnerTube API. Without these tokens, you'll see errors like:
- `Error: Request to https://www.youtube.com/youtubei/v1/browse failed with status code 400`
- API endpoints returning 500 errors
- Companion container unable to regenerate tokens

## Solution

The `rotate-tokens.sh` script automates token extraction, configuration update, and service restart.

## Files

- **`rotate-tokens.sh`** - Main token rotation script
- **`setup-auto-rotation.sh`** - Sets up automatic rotation via cron
- **`TOKEN-ROTATION-README.md`** - This file

## Quick Start

### Option 1: Manual Rotation (Run Once)

```bash
cd /home/dkt/invidious
./rotate-tokens.sh
```

The script will:
1. Try to automatically extract tokens from YouTube (requires Python or curl)
2. Fall back to manual input if automatic extraction fails
3. Backup your current `docker-compose.yml`
4. Update configuration with new tokens
5. Restart all services
6. Verify the deployment

### Option 2: Automatic Rotation (Recommended)

Set up automatic token rotation every 6 hours:

```bash
cd /home/dkt/invidious
./setup-auto-rotation.sh
```

This adds a cron job that runs the rotation script automatically.

## Manual Token Extraction

If automatic extraction fails, the script will prompt you to manually extract tokens:

1. Open https://www.youtube.com in your browser
2. Open Developer Tools (F12)
3. Go to the **Console** tab
4. Paste this code and press Enter:

```javascript
(async () => {
  const visitorData = document.cookie.match(/VISITOR_INFO1_LIVE=([^;]+)/)?.[1];
  console.log('visitor_data:', visitorData || 'Not found in cookies');

  // Try to extract poToken from the page
  const scripts = [...document.scripts];
  let poTokenFound = false;

  for (const script of scripts) {
    if (script.textContent.includes('poToken')) {
      const match = script.textContent.match(/"poToken":"([^"]+)"/);
      if (match) {
        console.log('po_token:', match[1]);
        poTokenFound = true;
        break;
      }
    }
  }

  if (!poTokenFound) {
    console.log('po_token: Not found in page scripts');
    console.log('\nAlternative: Check Network tab:');
    console.log('1. Filter by "youtubei"');
    console.log('2. Click any request');
    console.log('3. Look in Request payload > context > client > poToken');
  }
})();
```

5. Copy the `visitor_data` and `po_token` values
6. Paste them when the script prompts you

### Alternative: Network Tab Method

If the console method doesn't work:

1. Open Developer Tools (F12)
2. Go to the **Network** tab
3. Filter by `youtubei`
4. Refresh the page or click on a video
5. Click on any `youtubei/v1/*` request
6. Go to **Payload** or **Request** tab
7. Look for:
   - `context.client.visitorData` → this is your `visitor_data`
   - `context.client.poToken` → this is your `po_token`

## Features

### Automatic Token Extraction Methods

The script tries multiple methods to extract tokens automatically:

1. **Python Method** - Uses urllib to fetch YouTube page and extract tokens
2. **Curl Method** - Uses curl to fetch page and grep to parse tokens
3. **Node.js Method** - Uses Node.js https module to extract tokens
4. **Manual Input** - Prompts user if all automatic methods fail

### Backup & Safety

- Creates timestamped backups of `docker-compose.yml` in `backups/` directory
- Logs all operations to `token-rotation.log`
- Verifies deployment after restart

### Verification

After rotation, the script:
- Checks if containers are running
- Scans logs for errors
- Tests `/api/v1/stats` endpoint
- Tests `/api/v1/trending` endpoint (previously failing)

## Troubleshooting

### Script fails to extract tokens automatically

**Solution**: Follow the manual extraction steps above.

### "visitor_data is required" error

**Solution**: Make sure you're copying the full token value, including all characters.

### Services fail to start after rotation

**Solution**: Check the backup and restore it:
```bash
cd /home/dkt/invidious
cp backups/docker-compose.yml.TIMESTAMP docker-compose.yml
sudo docker compose up -d
```

### API still returns 400/500 errors after rotation

**Possible causes**:
1. **Tokens need time to propagate** - Wait 2-5 minutes
2. **Invalid tokens** - Extract new tokens and run script again
3. **Tokens expired** - YouTube tokens can expire; rotate again
4. **IP rate limiting** - YouTube may be rate-limiting your IP

**Solution**:
```bash
# Wait and check logs
sudo docker logs invidious-companion-1 --tail 50
sudo docker logs invidious-invidious-1 --tail 50

# If still failing, rotate again
./rotate-tokens.sh
```

### Companion still shows "Failed to get valid PO token" errors

This is normal during token regeneration. The companion will retry automatically. If errors persist for >10 minutes after rotation, the tokens may be invalid.

**Solution**: Run the rotation script again with fresh tokens.

## Token Lifespan

- **visitor_data**: Usually valid for several days to weeks
- **po_token**: Usually valid for several hours to days

Automatic rotation every 6 hours ensures tokens stay fresh.

## Monitoring

### Check rotation logs

```bash
# Manual rotation log
tail -f /home/dkt/invidious/token-rotation.log

# Cron rotation log (if auto-rotation enabled)
tail -f /home/dkt/invidious/token-rotation-cron.log
```

### Check container logs

```bash
# Companion logs
sudo docker logs -f invidious-companion-1

# Invidious logs
sudo docker logs -f invidious-invidious-1

# All services
sudo docker compose logs -f
```

### Check cron status

```bash
# View cron jobs
crontab -l

# Check if cron is running
sudo systemctl status cron
```

## Uninstalling Auto-Rotation

To remove automatic rotation:

```bash
crontab -e
# Delete the line containing: rotate-tokens.sh
```

## Advanced Usage

### Custom rotation interval

Edit the cron expression in `setup-auto-rotation.sh`:

```bash
# Every 3 hours
0 */3 * * * cd /home/dkt/invidious && ./rotate-tokens.sh

# Every 12 hours
0 */12 * * * cd /home/dkt/invidious && ./rotate-tokens.sh

# Daily at 3 AM
0 3 * * * cd /home/dkt/invidious && ./rotate-tokens.sh
```

### Test token extraction only (dry run)

```bash
# Extract tokens without updating config
cd /home/dkt/invidious
bash -c 'source rotate-tokens.sh && get_tokens'
```

### Manually update docker-compose.yml

If you prefer to manually edit:

1. Add to companion service:
```yaml
companion:
  environment:
    - SERVER_SECRET_KEY=mei8OshieZu7eim0
    - VISITOR_DATA=your_visitor_data_here
    - PO_TOKEN=your_po_token_here
```

2. Add to Invidious INVIDIOUS_CONFIG:
```yaml
INVIDIOUS_CONFIG: |
  # ... existing config ...
  visitor_data: "your_visitor_data_here"
  po_token: "your_po_token_here"
```

3. Restart services:
```bash
sudo docker compose down && sudo docker compose up -d
```

## FAQ

**Q: How often should I rotate tokens?**
A: Recommended every 6-12 hours for production use.

**Q: Can I run the script without sudo?**
A: The script needs sudo for docker commands. Add your user to the docker group to avoid sudo:
```bash
sudo usermod -aG docker $USER
# Then log out and back in
```

**Q: What if YouTube blocks my IP?**
A: You may need to:
- Wait a few hours before trying again
- Use a VPN or proxy
- Get tokens from a different IP/browser

**Q: Do tokens work across different IPs?**
A: Sometimes, but they're often tied to IP/browser. For best results, extract tokens from the same network where Invidious runs.

**Q: Can I share tokens across multiple Invidious instances?**
A: Not recommended. Each instance should have its own tokens to avoid rate limiting.

## Support

For issues with:
- **This script**: Check logs in `token-rotation.log`
- **Invidious**: https://github.com/iv-org/invidious/issues
- **Companion**: https://github.com/iv-org/invidious-companion/issues

## References

- Invidious Documentation: https://docs.invidious.io/
- YouTube Token Issue: https://github.com/iv-org/invidious/issues/4734
- Companion Documentation: https://github.com/iv-org/invidious-companion
