const defaultHeaders = {
  "Content-Type": "application/json",
  "Access-Control-Allow-Origin": "*",
};

const buildResponse = (statusCode, body) => ({
  statusCode,
  headers: defaultHeaders,
  body: JSON.stringify(body),
  isBase64Encoded: false,
});

module.exports = { buildResponse };
