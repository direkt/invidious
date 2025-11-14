# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Invidious is an open-source alternative front-end to YouTube, written in Crystal using the Kemal web framework. It provides a privacy-focused interface to YouTube without using the official YouTube API.

## Development Commands

### Building and Running
```bash
# Install dependencies
make get-libs

# Build the project (release mode by default)
make

# Build with specific options
make RELEASE=1 STATIC=0 MT=0

# Run the application
make run
# Or directly: ./invidious

# Build without generating binaries (verify compilation only)
make verify
```

### Testing and Code Quality
```bash
# Run tests
make test
# Or: crystal spec

# Format code
make format
# Or: crystal tool format

# Lint (requires ameba)
crystal lib/ameba/bin/ameba.cr
```

### Build Options
- `RELEASE=1` - Release build (default)
- `STATIC=1` - Static linking
- `MT=1` - Enable multi-threading (experimental, unstable)
- `API_ONLY=1` - Build without GUI
- `NO_DBG_SYMBOLS=1` - Strip debug symbols

### Database
```bash
# Run migrations
./invidious --migrate
```

## Architecture Overview

### Request Flow
1. **BeforeAll Handler** (`routes/before_all.cr`) - Processes all requests first:
   - Sets security headers (CSP, HSTS, X-Content-Type-Options)
   - Parses user preferences from cookies/headers
   - Authenticates users via session ID cookies
   - Generates CSRF tokens
   - Populates context with `preferences`, `user`, `sid`, `csrf_token`

2. **Route Dispatch** (`routing.cr`) - Macro-driven route registration:
   - Routes organized by category (web UI, API v1, image proxy)
   - Handlers in `routes/` directory process requests
   - Context data accessed via `env.get("preferences")`, `env.get?("user")`

3. **Business Logic** - Handler calls appropriate modules:
   - Video fetching: `videos.cr`, `videos/parser.cr`
   - Channel data: `channels/channels.cr`
   - User management: `user/user.cr`, `database/users.cr`
   - YouTube API: `yt_backend/youtube_api.cr`

### Core Components

**Web Framework (Kemal)**
- Main entry point: `src/invidious.cr`
- Routes defined in: `src/invidious/routes/**/*.cr`
- Custom handlers: `FilteredCompressHandler`, `APIHandler`, `AuthHandler`, `DenyFrame`
- Static files served from: `assets/`

**Database (PostgreSQL)**
- Module: `src/invidious/database/`
- Tables: channels, channel_videos, videos, users, session_ids, nonces, playlists, playlist_videos, annotations, statistics
- Migrations: `src/invidious/database/migrations/`
- Auto-integrity check on startup via `check_tables: true` in config
- User feeds use materialized views per user: `subscriptions_<hash(email)>`

**YouTube Backend**
- Module: `src/invidious/yt_backend/`
- Uses YouTube's internal `/youtubei/v1/*` API endpoints (not official API)
- Multiple client types supported: Web, Android, iOS, TV
- Connection pooling: `YoutubeConnectionPool` (separate pools for youtube.com, yt3.ggpht.com, ytimg.com subdomains)
- Video data extraction: `videos/parser.cr`

**Background Jobs**
- Base class: `jobs/base_job.cr`
- Jobs registered and started at application boot
- All jobs run in fibers (Crystal's green threads)
- Key jobs:
  - `RefreshChannelsJob` - Updates channel data (controlled by `channel_threads`, `channel_refresh_interval`)
  - `RefreshFeedsJob` - Updates user subscription feeds
  - `PullPopularVideosJob` - Maintains popular videos list
  - `SubscribeToFeedsJob` - PubSubHubbub integration (optional)
  - `NotificationJob` - PostgreSQL LISTEN/NOTIFY for user notifications
  - `ClearExpiredItemsJob` - Cleanup temporary data
  - `StatisticsRefreshJob` - Instance statistics

**Invidious Companion**
- External program for video stream URL generation and signature handling
- Recommended over deprecated `signature_server`
- Configured via `invidious_companion` array in config.yml
- Supports multiple instances for load balancing
- Requires `invidious_companion_key` (16 characters)

### Key Data Structures

**Video** (`videos.cr`)
- Primary struct with `id`, `info` (Hash stored as JSON), `updated`
- `info` field contains full YouTube API response for maximum fidelity
- Schema versioning via `SCHEMA_VERSION` constant
- Cache TTL: 10 minutes (unless schema version changes)

**Invidious::User** (`user/user.cr`)
- Fields: email, subscriptions (Array), watched (Array), notifications (Array), preferences, password, token
- Subscriptions and watch history stored as arrays of IDs
- Per-user materialized views for subscription feeds

**Preferences** (`user/preferences.cr`)
- Comprehensive user settings (language, theme, quality, etc.)
- Custom converters for complex types (BoolToString, ClampInt, URIConverter)
- Stored in database for authenticated users, cookies for anonymous
- Short video filtering: `hide_shorts` and `shorts_max_length` (1-300 seconds, default 60)

**Channel Models**
- `InvidiousChannel` - Cached channel metadata
- `ChannelVideo` - Individual video in channel feed

**Playlist Models**
- `Playlist` - YouTube playlists
- `InvidiousPlaylist` - User-created playlists
- `PlaylistVideo` - Videos in playlists with index

### Configuration

**Config File:** `config/config.yml` (copy from `config/config.example.yml`)

**Mandatory Settings:**
- `db` or `database_url` - PostgreSQL connection
- `domain` - FQDN of instance (required for public instances)
- `hmac_key` - Random string for CSRF/cookies (generate with: `pwgen 20 1`)

**Important Settings:**
- `invidious_companion` - Array of companion instances (recommended)
- `invidious_companion_key` - 16-character API key for companion
- `https_only` - Set to true if behind HTTPS reverse proxy
- `external_port` - Port seen by users (if behind reverse proxy)
- `pool_size` - HTTP connection pool capacity (default: 100)
- `channel_threads` / `feed_threads` - Background job parallelism
- `statistics_enabled` - Required for public instances
- `use_pubsub_feeds` - PubSubHubbub for instant channel updates

**Configuration Priority:**
1. Environment variables (`INVIDIOUS_*`)
2. YAML config file
3. Compiled defaults

## Code Patterns

### Macro-Driven Architecture
- Route registration uses macros to auto-generate Kemal handlers
- Job system uses macros to discover all `BaseJob` subclasses and generate config struct
- Getter/setter generation for Video attributes via macros

### Database Serialization
```crystal
struct MyModel
  include DB::Serializable

  property id : String
  property title : String

  # Custom converter for complex types
  @[DB::Field(converter: MyConverter)]
  property data : Hash(String, JSON::Any)
end
```

### Context Storage (Kemal)
```crystal
# In handler
env.set "preferences", preferences
env.set "user", user

# Later access
prefs = env.get("preferences").as(Preferences)
user = env.get?("user").try &.as(User)  # Optional
```

### Error Handling
- Custom exceptions: `InfoException`, `NotFoundException`, `VideoNotAvailableException`
- Error routes: `routes/errors.cr`
- 404/500 handlers in main file

### Connection Pooling Pattern
```crystal
YT_POOL.client do |client|
  # Use client for YouTube requests
  # Automatically returned to pool when block exits
end
```

## Testing

**Test Framework:** Spectator (BDD-style)
**Test Location:** `spec/`
**Run Tests:** `make test` or `crystal spec`

## Important Notes

### Crystal Language
- Statically typed, compiled language with Ruby-like syntax
- Requires Crystal compiler (>= 1.10.0, < 2.0.0)
- Use `crystal tool format` before committing
- Type inference is strong - explicit types often unnecessary

### YouTube Integration
- Does **not** use official YouTube API (uses internal InnerTube API)
- YouTube can change their API at any time - breakage possible
- Client types must match YouTube's expectations (user agents, versions)
- Rate limiting can occur - `force_resolve: ipv4` or `ipv6` may help
- Consider `po_token` and `visitor_data` if blocked by "This helps protect our community"

### Database
- PostgreSQL is required (SQLite3 dependency is not for production use)
- Tables auto-created/updated if `check_tables: true`
- Materialized views used for user feeds (performance optimization)
- Migration system is present but basic - check migrations before running

### Performance
- Fiber-based concurrency (not OS threads unless `MT=1`)
- Connection pooling is critical for performance
- Video data cached in database with TTL
- Background jobs run continuously in separate fibers

### Security
- CSRF protection via HMAC tokens
- Session-based authentication
- Security headers set in BeforeAll handler
- Bcrypt for password hashing (cost: 10)
- Content-Security-Policy enforced

## Common Tasks

### Adding a New Route
1. Create handler in `src/invidious/routes/`
2. Define module with handler methods
3. Register route in `src/invidious/routing.cr` using route macros

### Adding a New Job
1. Create class extending `Invidious::Jobs::BaseJob` in `src/invidious/jobs/`
2. Implement `begin` method
3. Register in `src/invidious.cr`: `Invidious::Jobs.register MyJob.new(...)`
4. Add config section to `config.example.yml` under `jobs:` if needed

### Modifying Database Schema
1. Create migration in `src/invidious/database/migrations/`
2. Extend `Migration` class with `up` and `down` methods
3. Run: `./invidious --migrate`

### Adding API Endpoint
1. Create/modify handler in `src/invidious/routes/api/v1/`
2. Implement JSON serialization via `to_json` method
3. Register route in routing module

## File Locations

- **Main entry:** `src/invidious.cr`
- **Routes:** `src/invidious/routes/`
- **Database:** `src/invidious/database/`
- **YouTube backend:** `src/invidious/yt_backend/`
- **Jobs:** `src/invidious/jobs/`
- **Models:** `src/invidious/{videos,channels,user,playlists}.cr`
- **Helpers:** `src/invidious/helpers/`
- **Frontend:** `src/invidious/frontend/`
- **Tests:** `spec/`
- **Assets:** `assets/`
- **Config:** `config/config.yml`
- **Database migrations:** `src/invidious/database/migrations/`

## Documentation

- Official docs: https://docs.invidious.io/
- API documentation: https://docs.invidious.io/api/
- Installation: https://docs.invidious.io/installation/
- Crystal docs: https://crystal-lang.org/reference/
