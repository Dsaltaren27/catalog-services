const {redis}=require ('../utils/redisClient');

exports.handler=async ()=>{

    try {
        const data=await redis.get('catalog');
        return {
            statusCode:200,
            body:data ? data : JSON.stringify([])
        };
    } catch (e) {
        return {
            statusCode:500,
            body:'Error fetching catalog'
        };
    }
};