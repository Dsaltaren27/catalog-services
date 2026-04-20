import redis from 'ioredis';

export const redis=new redis.Cluster([
    {
        host: process.env.REDIS_HOST,
        port: 6379,
        
    }
]);          