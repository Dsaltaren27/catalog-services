// getCatalog.js
const { redis } = require("../utils/redisClient");
const { buildResponse } = require("../utils/httpResponse");

exports.handler = async (event, context) => {
  context.callbackWaitsForEmptyEventLoop = false;

  try {
    const cacheKey = process.env.CATALOG_CACHE_KEY || "catalog:latest";
    const data = await redis.get(cacheKey);

    return buildResponse(200, data ? JSON.parse(data) : []);
  } catch (error) {
    return buildResponse(500, {
      message: "Error fetching catalog",
    });
  }
};
