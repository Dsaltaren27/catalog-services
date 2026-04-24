# Catalog 

## Descripción

Este microservicio se encarga de la gestión del catálogo de servicios dentro del sistema de pagos distribuido. Permite cargar un archivo CSV con la información de los servicios y exponerlos mediante un endpoint para su consumo desde el frontend.

La arquitectura implementa un enfoque híbrido utilizando Amazon S3 como almacenamiento persistente, Redis Cluster como capa de lectura rápida y AWS Lambda para el procesamiento serverless.

---

## Arquitectura

Cliente
   ↓
API Gateway
   ↓
Lambda (POST /catalog/update)
   ↓
S3 (almacenamiento CSV)
   ↓
Procesamiento CSV
   ↓
Redis Cluster (cache del catálogo)
   ↓
Lambda (GET /catalog)
   ↓
Cliente

---

## Endpoints

### POST /catalog/update

Permite actualizar el catálogo de servicios a partir de un archivo CSV.

Request:

```json
{
  "file": "contenido-del-csv-como-string"
}
