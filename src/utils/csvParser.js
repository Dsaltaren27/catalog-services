
const parseCSV = async (csvContent) => {
  const lines = csvContent.split("\n");


  const headers = lines[0].split(",").map(h => h.trim());

  const results = lines.slice(1).map(line => {

  
    if (!line.trim()) return null;

    const values = line.split(",");
    const obj = {};

    headers.forEach((header, index) => {
      obj[header] = values[index]?.trim();
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
  }).filter(Boolean); 

  return results;
};

module.exports = { parseCSV };