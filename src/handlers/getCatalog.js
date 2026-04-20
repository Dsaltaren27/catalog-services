import {redis} from '../utils/redisClient.js';

export const handler=async ()=>{

    try {
        const data=await redis.get('catalog');
        return {
            statusCode:200,
            body:JSON.stringify(data)
        };
    } catch (e) {
        return {
            statusCode:500,
            body:'Error fetching catalog'
        };
    }
};