const { Readable } = require("stream");
const csv = require("csv-parser");

const numericFields = new Set(["id", "precio_mensual"]);

const headerMap = {
  ID: "id",
  Categoria: "categoria",
  Proveedor: "proveedor",
  Servicio: "servicio",
  Plan: "plan",
  "Precio Mensual (US$)": "precio_mensual",
  "Velocidad/Detalles": "detalles",
  Estado: "estado",
};

const normalizeHeader = (header) => {
  const trimmedHeader = header.replace(/^\uFEFF/, "").trim();
  return headerMap[trimmedHeader] || trimmedHeader;
};

const normalizeRow = (row) =>
  Object.entries(row).reduce((accumulator, [key, value]) => {
    const normalizedKey = normalizeHeader(key);
    const normalizedValue = typeof value === "string" ? value.trim() : value;

    accumulator[normalizedKey] = numericFields.has(normalizedKey)
      ? Number(normalizedValue)
      : normalizedValue;

    return accumulator;
  }, {});

const parseCSV = async (csvContent) =>
  new Promise((resolve, reject) => {
    const results = [];

    Readable.from([csvContent])
      .pipe(
        csv({
          mapHeaders: ({ header }) => normalizeHeader(header),
        })
      )
      .on("data", (row) => {
        results.push(normalizeRow(row));
      })
      .on("end", () => {
        resolve(results);
      })
      .on("error", reject);
  });

module.exports = { parseCSV };
