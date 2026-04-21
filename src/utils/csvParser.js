const parseCSV = async (csvContent) => {
  const lines = csvContent.split("\n");
  const headers = lines[0].split(",");

  const results = lines.slice(1).map(line => {
    const values = line.split(",");
    const obj = {};

    headers.forEach((header, index) => {
      obj[header.trim()] = values[index]?.trim();
    });

    return {
      id: Number(obj.id),
      categoria: obj.categoria,
      proveedor: obj.proveedor,
      servicio: obj.servicio,
      plan: obj.plan,
      precio_mensual: Number(obj.precio_mensual),
      detalles: obj.detalles,
      estado: obj.estado,
    };
  });

  return results;
};

module.exports = { parseCSV };