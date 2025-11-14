# Automated Key Setup for Invidious Docker

This automation script generates secure keys for your Invidious Docker installation using `pwgen`.

## Quick Start

```bash
./setup-keys.sh
```

That's it! The script will:
- ✓ Generate a secure 20-character HMAC key
- ✓ Generate a secure 16-character Companion key
- ✓ Update docker-compose.yml with the new keys
- ✓ Create a timestamped backup before making changes

## What Keys Are Generated?

1. **HMAC_KEY** (20 characters)
   - Used for CSRF protection and session cookies
   - Located at: `INVIDIOUS_CONFIG.hmac_key`

2. **COMPANION_KEY** (16 characters)
   - Used for secure communication with Invidious Companion
   - Located at: `INVIDIOUS_CONFIG.invidious_companion_key`
   - Also set as: `companion.environment.SERVER_SECRET_KEY`

## Requirements

- **pwgen** must be installed:
  ```bash
  # Debian/Ubuntu
  sudo apt-get install pwgen

  # RHEL/CentOS
  sudo yum install pwgen

  # macOS
  brew install pwgen
  ```

## Manual Key Generation

If you prefer to generate keys manually:

```bash
# Generate HMAC key (20 characters)
pwgen -s 20 1

# Generate Companion key (16 characters)
pwgen -s 16 1
```

Then manually update the three locations in `docker-compose.yml`:
1. Line ~35: `hmac_key: "YOUR_HMAC_KEY"`
2. Line ~36: `invidious_companion_key: "YOUR_COMPANION_KEY"`
3. Line ~51: `SERVER_SECRET_KEY=YOUR_COMPANION_KEY`

## Re-running the Script

You can run the script multiple times safely. Each run:
- Creates a new timestamped backup
- Generates fresh keys
- Updates the configuration

**Warning:** Running this on a production instance will invalidate existing sessions and require users to log in again.

## Security Best Practices

- **Never** commit docker-compose.yml with real keys to version control
- **Never** share your keys publicly
- Keep backup files in a secure location
- Use different keys for each instance
- Rotate keys periodically for enhanced security

## Backup Files

Backups are created with the format: `docker-compose.yml.backup.YYYYMMDD_HHMMSS`

To restore from a backup:
```bash
cp docker-compose.yml.backup.YYYYMMDD_HHMMSS docker-compose.yml
```

## After Setup

Once keys are configured:

```bash
# Start the services
docker-compose up -d

# View logs
docker-compose logs -f

# Check service status
docker-compose ps
```

## Troubleshooting

**Script fails with "pwgen: command not found"**
- Install pwgen (see Requirements section)

**Script fails with "docker-compose.yml not found"**
- Run the script from the Invidious root directory

**Services fail to start after key update**
- Check logs: `docker-compose logs`
- Verify keys match between Invidious and Companion
- Ensure keys don't contain special characters that need escaping

## Documentation

For more information, see:
- [Invidious Installation Docs](https://docs.invidious.io/installation/)
- [CLAUDE.md](./CLAUDE.md) - Project development guide
