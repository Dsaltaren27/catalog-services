import csv from 'csv-parser';
import {Readable} from 'stream';

export const parseCSV = async (csvContent) => {
    const results = [];
    
    await new Promise((resolve, reject) => {
        Readable.from([csvContent])
            .pipe(csv())
            .on('data', (data) => {
                results.push({
                    id: Number(data.id),
                    Categoria: data.Categoria,
                    proveedor: data.proveedor,
                    servicio: data.servicio,
                    plan: data.plan,
                    precio_mesual: Number(data.precio_mensual),
                    detalles: data.detalles,
                    estado: data.estado,
                });
            })
            .on('end', resolve)
            .on('error', reject);

    });
    return results;
};
