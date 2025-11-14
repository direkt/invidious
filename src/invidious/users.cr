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

def get_subscription_feed(user, max_results = 40, page = 1)
  limit = max_results.clamp(0, MAX_ITEMS_PER_PAGE)
  offset = (page - 1) * limit

  notification_ids = Invidious::Database::Users.select_notifications(user)
  view_name = "subscriptions_#{sha256(user.email)}"

  preferences = user.preferences
  hide_shorts = preferences.hide_shorts
  shorts = [] of ChannelVideo

  LOGGER.debug("get_subscription_feed: hide_shorts=#{hide_shorts}, shorts_max_length=#{preferences.shorts_max_length}, notifications_only=#{preferences.notifications_only}")

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
