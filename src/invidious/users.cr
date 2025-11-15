require "crypto/bcrypt/password"

# Materialized views may not be defined using bound parameters (`$1` as used elsewhere)
MATERIALIZED_VIEW_SQL = ->(email : String) { "SELECT cv.* FROM channel_videos cv WHERE EXISTS (SELECT subscriptions FROM users u WHERE cv.ucid = ANY (u.subscriptions) AND u.email = E'#{email.gsub({'\'' => "\\'", '\\' => "\\\\"})}') ORDER BY published DESC" }

def create_user(sid, email, password)
  password = Crypto::Bcrypt::Password.create(password, cost: 10)
  token = Base64.urlsafe_encode(Random::Secure.random_bytes(32))

  user = Invidious::User.new({
    updated:           Time.utc,
    notifications:     [] of String,
    subscriptions:     [] of String,
    email:             email,
    preferences:       Preferences.new(CONFIG.default_user_preferences.to_tuple),
    password:          password.to_s,
    token:             token,
    watched:           [] of String,
    feed_needs_update: true,
  })

  return user, sid
end

def get_subscription_feed(user, max_results = 40, page = 1, requesting_shorts_tab = false)
  limit = max_results.clamp(0, MAX_ITEMS_PER_PAGE)
  offset = (page - 1) * limit

  notification_ids = Invidious::Database::Users.select_notifications(user)
  view_name = "subscriptions_#{sha256(user.email)}"

  preferences = user.preferences
  hide_shorts = preferences.hide_shorts
  shorts = [] of ChannelVideo

  LOGGER.debug("get_subscription_feed: hide_shorts=#{hide_shorts}, shorts_max_length=#{preferences.shorts_max_length}, notifications_only=#{preferences.notifications_only}, requesting_shorts_tab=#{requesting_shorts_tab}")

  if preferences.notifications_only && !notification_ids.empty?
    # Only show notifications
    notifications = Invidious::Database::ChannelVideos.select(notification_ids)
    videos = [] of ChannelVideo

    if hide_shorts
      short_notifications, regular_notifications = notifications.partition { |video| short_video?(video, preferences) }
      shorts.concat(short_notifications)
      notifications = regular_notifications
    end

    notifications.sort_by!(&.published).reverse!

    case preferences.sort
    when "alphabetically"
      notifications.sort_by!(&.title)
    when "alphabetically - reverse"
      notifications.sort_by!(&.title).reverse!
    when "channel name"
      notifications.sort_by!(&.author)
    when "channel name - reverse"
      notifications.sort_by!(&.author).reverse!
    else nil # Ignore
    end
  else
    notifications = [] of ChannelVideo

    if preferences.latest_only
      if preferences.unseen_only
        # Show latest video from a channel that a user hasn't watched
        # "unseen_only" isn't really correct here, more accurate would be "unwatched_only"

        if user.watched.empty?
          values = "'{}'"
        else
          values = "VALUES #{user.watched.map { |id| %(('#{id}')) }.join(",")}"
        end
        videos = PG_DB.query_all("SELECT DISTINCT ON (ucid) * FROM #{view_name} WHERE NOT id = ANY (#{values}) ORDER BY ucid, published DESC", as: ChannelVideo)
      else
        # Show latest video from each channel

        videos = PG_DB.query_all("SELECT DISTINCT ON (ucid) * FROM #{view_name} ORDER BY ucid, published DESC", as: ChannelVideo)
      end

      videos.sort_by!(&.published).reverse!
    else
      if preferences.unseen_only
        # Only show unwatched

        if user.watched.empty?
          values = "'{}'"
        else
          values = "VALUES #{user.watched.map { |id| %(('#{id}')) }.join(",")}"
        end
        videos = PG_DB.query_all("SELECT * FROM #{view_name} WHERE NOT id = ANY (#{values}) ORDER BY published DESC LIMIT $1 OFFSET $2", limit, offset, as: ChannelVideo)
      else
        # Sort subscriptions as normal

        videos = PG_DB.query_all("SELECT * FROM #{view_name} ORDER BY published DESC LIMIT $1 OFFSET $2", limit, offset, as: ChannelVideo)
      end
    end

    if hide_shorts
      short_videos, regular_videos = videos.partition { |video| short_video?(video, preferences) }
      shorts.concat(short_videos)
      videos = regular_videos
      
      # If requesting shorts tab, we need to paginate shorts separately
      # Since shorts are filtered from videos, we need to fetch from the beginning
      # and collect enough shorts for pagination
      if requesting_shorts_tab
        # Calculate how many shorts we need for the current page
        shorts_needed_start = (page - 1) * limit
        shorts_needed_end = shorts_needed_start + limit
        
        # Start fetching from the beginning (offset 0) to collect all shorts in order
        # Fetch in batches until we have enough shorts for the current page
        fetch_offset = 0
        fetch_batch_size = limit * 3 # Fetch larger batches to reduce queries
        max_fetches = 20 # Safety limit to prevent infinite loops
        
        fetch_count = 0
        while shorts.size < shorts_needed_end && fetch_count < max_fetches
          batch_videos = PG_DB.query_all("SELECT * FROM #{view_name} ORDER BY published DESC LIMIT $1 OFFSET $2", fetch_batch_size, fetch_offset, as: ChannelVideo)
          break if batch_videos.empty?
          
          batch_shorts, _ = batch_videos.partition { |video| short_video?(video, preferences) }
          shorts.concat(batch_shorts)
          
          fetch_offset += fetch_batch_size
          fetch_count += 1
          
          # If this batch had no shorts and we still don't have enough, we might be done
          break if batch_shorts.empty? && shorts.size < shorts_needed_end
        end
        
        # Sort shorts by published date (newest first)
        shorts.sort_by!(&.published).reverse!
        
        # Paginate the shorts array for the current page
        shorts = shorts[shorts_needed_start, limit]? || shorts[shorts_needed_start..] || [] of ChannelVideo
      end
    end

    case preferences.sort
    when "published - reverse"
      videos.sort_by!(&.published)
    when "alphabetically"
      videos.sort_by!(&.title)
    when "alphabetically - reverse"
      videos.sort_by!(&.title).reverse!
    when "channel name"
      videos.sort_by!(&.author)
    when "channel name - reverse"
      videos.sort_by!(&.author).reverse!
    else nil # Ignore
    end

    notifications = videos.select { |v| notification_ids.includes? v.id }
    videos = videos - notifications
  end

  shorts.sort_by!(&.published).reverse!
  LOGGER.debug("get_subscription_feed: returning #{videos.size} videos, #{notifications.size} notifications, #{shorts.size} shorts")
  return videos, notifications, shorts
end

private def short_video?(video : ChannelVideo, preferences : Preferences) : Bool
  return false unless preferences.hide_shorts

  # Don't classify live videos or upcoming premieres as shorts
  return false if video.live_now
  return false if video.premiere_timestamp

  length = video.length_seconds
  # Include videos with unknown length (0) as they might be shorts
  # Also include videos with known length that are <= shorts_max_length
  length == 0 || (length > 0 && length <= preferences.shorts_max_length)
end
