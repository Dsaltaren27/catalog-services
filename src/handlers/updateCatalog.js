import { S3Client ,PutObjectCommand} from "@aws-sdk/client-s3";
import { v4 as uuidv4 } from 'uuid';
import { parseCSV } from '../utils/csvParser.js';
import { redis } from '../utils/redisClient.js';


const s3= new S3Client({region: process.env.AWS_REGION});

export const handler=async (event)=>{
    try {
        const {file}=JSON.parse(event.body || '{}');
        if(!file) return {
            statusCode:400,
            body:'CSV required'};
        
// Subir el archivo a S3
            const key=`catalogs/${uuidv4()}.csv`;
            await s3.send(new PutObjectCommand({
                Bucket: process.env.S3_BUCKET,
                Key: key,
                Body: file,
            }));

// parsear el CSV
            const catalog=await parseCSV(file);

// reemplazar en Redis
            await redis.set('catalog', JSON.stringify(catalog));

            return {
                statusCode:200,
                body:'Catalog updated successfully'
            };
    } catch (e) {

        return {
            statusCode:500,
            body:'Error updating catalog'
        };
    }   
};                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    
