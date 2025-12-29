require "redis"

REDIS = Redis.new(url: ENV.fetch("REDIS_URL", "redis://redis:6379/0"))
