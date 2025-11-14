# How to Get YouTube po_token and visitor_data

## Quick Method (Browser Console)

### Step 1: Get visitor_data

1. Open YouTube (youtube.com) in your browser
2. Press **F12** to open Developer Tools
3. Go to the **Console** tab
4. Type this command and press Enter:
   ```javascript
   ytcfg.get('VISITOR_DATA')
   ```
5. Copy the string that appears (without quotes)
   - Example: `CgtHZjFLSHhZcThRTSjnq8G5BjIKCgJDQRIEGgAgOA%3D%3D`

### Step 2: Get po_token

1. With YouTube still open and Developer Tools open (F12)
2. Go to the **Network** tab
3. Filter by typing: `player` in the filter box
4. Play **any video** on YouTube
5. Look for a request named `player?key=...`
6. Click on it, then click the **Payload** or **Request** tab
7. Look for `serviceIntegrityDimensions` -> `poToken`
8. Copy the entire token string
   - Example: `MnQBWFhSb85V2gEYhMg5tve...` (very long string)

### Step 3: Update docker-compose.yml

Edit your docker-compose.yml and replace the commented lines:

```yaml
# In the invidious service (around line 39):
visitor_data: "YOUR_VISITOR_DATA_HERE"
po_token: "YOUR_PO_TOKEN_HERE"

# In the companion service (around line 53):
- VISITOR_DATA=YOUR_VISITOR_DATA_HERE
- PO_TOKEN=YOUR_PO_TOKEN_HERE
```

### Step 4: Restart containers

```bash
sudo docker-compose down
sudo docker-compose up -d
```

## Alternative: Using YouTube Music

If the above doesn't work, try YouTube Music instead:

1. Open **music.youtube.com**
2. Follow the same steps as above
3. The po_token from YouTube Music will be prefixed with `mweb+gvs.`

## Important Notes

- **Tokens expire**: They typically last 12-24 hours, then you'll need new ones
- **Privacy**: Using tokens makes your instance more traceable by YouTube
- **Same tokens**: Use the SAME tokens for both Invidious and Companion services
- **No spaces**: Make sure there are no extra spaces when copying

## Token Expiry Signs

When tokens expire, you'll see:
- "Error: non 200 status code. Youtube API returned status code 400"
- Trending page stops working
- Some videos fail to load

Solution: Get fresh tokens and update the config again.

## Automation Option

For automatic token rotation, check out:
- https://github.com/catspeed-cc/invidious-token-updater

This script can periodically fetch and update tokens for you (advanced users).
