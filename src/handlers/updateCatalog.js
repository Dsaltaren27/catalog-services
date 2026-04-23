// updateCatalog.js
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const crypto = require("crypto");
const { parseCSV } = require("../utils/csvParser");
const { redis } = require("../utils/redisClient");

const s3 = new S3Client({ region: process.env.AWS_REGION });

exports.handler = async (event, context) => {
  context.callbackWaitsForEmptyEventLoop = false;

  try {
    const body = JSON.parse(event.body || "{}");

    const file = body.file;

    if (!file) {
      return {
        statusCode: 400,
        body: JSON.stringify({ message: "CSV required" })
      };
    }

    // CORREGIDO: mejor organización en S3
    const key = `catalog/${crypto.randomUUID()}.csv`;

    await s3.send(new PutObjectCommand({
      Bucket: process.env.BUCKET_NAME,
      Key: key,
      Body: file,
    }));

    const catalog = await parseCSV(file);

    await redis.set("catalog:latest", JSON.stringify(catalog));

    return {
      statusCode: 200,
      body: JSON.stringify({
        message: "Catalog updated successfully",
        items: catalog.length
      })
    };

  } catch (error) {
    console.error("Error en updateCatalog:", error);

    return {
      statusCode: 500,
      body: JSON.stringify({
        message: "Error updating catalog"
      })
    };
  }
};