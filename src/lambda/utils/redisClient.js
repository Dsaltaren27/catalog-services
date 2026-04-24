const Redis = require("ioredis");

const redis = new Redis({
  host: process.env.REDIS_HOST,
  port: Number(process.env.REDIS_PORT || 6379),
  connectTimeout: 5000,
  maxRetriesPerRequest: 1,
  lazyConnect: true,
});

redis.on("connect", () => console.log("Redis conectado"));

redis.on("error", (err) => {
  console.error("Redis error:", err);
});

module.exports = { redis };
