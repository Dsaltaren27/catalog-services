// updateCatalog.js
const { S3Client, GetObjectCommand } = require("@aws-sdk/client-s3");
const { parseCSV } = require("../utils/csvParser");
const { buildResponse } = require("../utils/httpResponse");
const { redis } = require("../utils/redisClient");

const s3 = new S3Client({ region: process.env.AWS_REGION });

const streamToString = async (stream) => {
  const chunks = [];

  for await (const chunk of stream) {
    chunks.push(Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk));
  }

  return Buffer.concat(chunks).toString("utf-8");
};

exports.handler = async (event, context) => {
  context.callbackWaitsForEmptyEventLoop = false;

  try {
    const records = event.Records || [];

    if (records.length === 0) {
      return buildResponse(400, { message: "No S3 records received" });
    }

    const cacheKey = process.env.CATALOG_CACHE_KEY || "catalog:latest";
    let processedFiles = 0;
    let totalItems = 0;

    for (const record of records) {
      const bucketName = record.s3?.bucket?.name;
      const objectKey = decodeURIComponent(record.s3?.object?.key || "").replace(/\+/g, " ");

      if (!bucketName || !objectKey) {
        continue;
      }

      const response = await s3.send(
        new GetObjectCommand({
          Bucket: bucketName,
          Key: objectKey,
        })
      );

      const csvContent = await streamToString(response.Body);
      const catalog = await parseCSV(csvContent);

      await redis.set(cacheKey, JSON.stringify(catalog));

      processedFiles += 1;
      totalItems = catalog.length;
    }

    return buildResponse(200, {
      message: "Catalog processed successfully",
      processedFiles,
      items: totalItems,
    });
  } catch (error) {
    console.error("Error en updateCatalog:", error);

    return buildResponse(500, {
      message: "Error updating catalog",
    });
  }
};
