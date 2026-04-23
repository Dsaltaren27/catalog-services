// getCatalog.js
const { redis } = require('../utils/redisClient');

exports.handler = async (event, context) => {
  context.callbackWaitsForEmptyEventLoop = false;

  try {

    const data = await redis.get('catalog');
    
    const data = await redis.get("catalog:latest");

    return {
      statusCode: 200,
      body: JSON.stringify(
        data ? JSON.parse(data) : [] 
      ),
    };

  } catch (error) {
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: "Error fetching catalog"
      })
    };
  }
};