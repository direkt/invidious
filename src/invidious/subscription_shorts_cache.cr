struct SubscriptionShortsCacheEntry
  getter expires_at : Time
  getter shorts : Array(ChannelVideo)
  getter max_length : Int32

  def initialize(@shorts : Array(ChannelVideo), @max_length : Int32, ttl : Time::Span)
    @expires_at = Time.utc + ttl
  end

  def expired?(max_length : Int32) : Bool
    Time.utc > @expires_at || max_length != @max_length
  end

  def covers?(required_count : Int32) : Bool
    @shorts.size >= required_count
  end
end

module Invidious::SubscriptionShortsCache
  extend self

  CACHE_TTL      = 2.minutes
  MIN_FETCH      = 40
  MAX_FETCH      = 600
  MAX_CACHE_SIZE = 512

  @@cache = {} of String => SubscriptionShortsCacheEntry
  @@mutex = Mutex.new

  def fetch(email : String, max_length : Int32, required_count : Int32, &block : Int32 -> Array(ChannelVideo)) : Array(ChannelVideo)
    required = required_count.clamp(1, MAX_FETCH)

    if entry = cached_entry(email, max_length, required)
      return entry.shorts.dup
    end

    fetch_limit = Math.max(required, MIN_FETCH)
    fetch_limit = Math.min(fetch_limit, MAX_FETCH)
    shorts = yield fetch_limit

    store(email, SubscriptionShortsCacheEntry.new(shorts, max_length, CACHE_TTL))
    shorts.dup
  end

  def invalidate(email : String)
    @@mutex.synchronize { @@cache.delete(email) }
  end

  def clear
    @@mutex.synchronize { @@cache.clear }
  end

  private def cached_entry(email : String, max_length : Int32, required : Int32)
    @@mutex.synchronize do
      if entry = @@cache[email]?
        return entry unless entry.expired?(max_length) || !entry.covers?(required)
        @@cache.delete(email)
      end
    end
    nil
  end

  private def store(email : String, entry : SubscriptionShortsCacheEntry)
    @@mutex.synchronize do
      @@cache[email] = entry
      trim_cache if @@cache.size > MAX_CACHE_SIZE
    end
  end

  private def trim_cache
    while @@cache.size > MAX_CACHE_SIZE
      oldest = @@cache.min_by { |_, entry| entry.expires_at }
      break unless oldest
      @@cache.delete(oldest[0])
    end
  end
end

