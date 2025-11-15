require "uri"

module Invidious::HttpServer
  module Utils
    extend self

    def proxy_video_url(raw_url : String, *, region : String? = nil, absolute : Bool = false)
      url = URI.parse(raw_url)

      # Add some URL parameters
      params = url.query_params
      params["host"] = url.host.not_nil! # Should never be nil, in theory
      params["region"] = region if !region.nil?
      url.query_params = params

      if absolute
        return "#{HOST_URL}#{url.request_target}"
      else
        return url.request_target
      end
    end

    def add_params_to_url(url : String | URI, params : URI::Params) : URI
      url = URI.parse(url) if url.is_a?(String)

      # Merge with existing params, replacing any duplicates
      existing_params = url.query_params
      params.each do |key, value|
        existing_params[key] = value
      end
      url.query_params = existing_params

      return url
    end
  end
end
