# Coupons Backend - .NET Microservices

Backend de microservicios para el sistema de campaña de cupones promocionales, construido con .NET 9.0.

## 📚 Documentación

- **[API_EXAMPLES.md](./API_EXAMPLES.md)** - Ejemplos completos de peticiones API
- **[TESTING.md](./TESTING.md)** - Guía de pruebas locales
- **[REQUEST_EXAMPLES_GUIDE.md](./REQUEST_EXAMPLES_GUIDE.md)** - Cómo usar los ejemplos (Postman, REST Client, etc.)
- **[IMPLEMENTATION.md](./IMPLEMENTATION.md)** - Resumen de implementación

## 🚀 Inicio Rápido

```powershell
# Terminal 1: RedeemService
cd src\RedeemService\RedeemService
dotnet run

# Terminal 2: CampaignService
cd src\CampaignService\CampaignService
dotnet run

# Terminal 3: Ejecutar pruebas
.\test-local.ps1
```

Ver [TESTING.md](./TESTING.md) para más detalles.

## Arquitectura

Este repositorio contiene tres componentes principales:

### 1. **RedeemService** (Microservicio de Canje)
- **Puerto**: 8080/8081
- **Endpoints**:
  - `POST /api/redeem` - Canjear un cupón
  - `GET /api/coupon/{code}` - Consultar estado de cupón
  - `GET /api/health` - Health check

### 2. **CampaignService** (Microservicio de Campañas)
- **Puerto**: 8080/8081
- **Endpoints**:
  - `POST /api/campaigns/{id}/generate` - Solicitar generación masiva
  - `GET /api/health` - Health check

### 3. **CouponGenerator** (Job ACI)
- Aplicación de consola para generación masiva de cupones
- Se ejecuta on-demand en Azure Container Instances (ACI)
- Variables de entorno:
  - `AMOUNT` - Cantidad de cupones a generar
  - `PREFIX` - Prefijo para los cupones
  - `CAMPAIGN_ID` - ID de la campaña

## Estructura del Proyecto

```
coupons-backend-dotnet/
├── src/
│   ├── RedeemService/           # Servicio de canje
│   │   ├── RedeemService/
│   │   │   ├── Controllers/
│   │   │   ├── Services/
│   │   │   └── Program.cs
│   │   └── Dockerfile
│   ├── CampaignService/         # Servicio de campañas
│   │   ├── CampaignService/
│   │   │   ├── Controllers/
│   │   │   ├── Services/
│   │   │   └── Program.cs
│   │   └── Dockerfile
│   ├── CouponGenerator/         # Generador batch
│   │   ├── CouponGenerator/
│   │   │   └── Program.cs
│   │   └── Dockerfile
│   └── Shared/
│       └── Shared.Models/       # Modelos y DTOs compartidos
│           ├── Models/
│           └── DTOs/
├── tests/
└── CouponsBackend.sln
```

## Requisitos

- .NET 9.0 SDK
- Docker (para construcción de imágenes)

## Desarrollo Local

### Compilar la solución
```bash
dotnet restore
dotnet build
```

### Ejecutar RedeemService
```bash
cd src/RedeemService/RedeemService
dotnet run
```

### Ejecutar CampaignService
```bash
cd src/CampaignService/CampaignService
dotnet run
```

### Ejecutar CouponGenerator (local)
```bash
cd src/CouponGenerator/CouponGenerator
$env:AMOUNT="1000"
$env:PREFIX="TEST"
$env:CAMPAIGN_ID="test-campaign"
dotnet run
```

## Docker

### Construir imágenes

Desde la raíz del repositorio:

```bash
# RedeemService
docker build -f src/RedeemService/Dockerfile -t redeem-service:latest .

# CampaignService
docker build -f src/CampaignService/Dockerfile -t campaign-service:latest .

# CouponGenerator
docker build -f src/CouponGenerator/Dockerfile -t coupon-generator:latest .
```

### Ejecutar contenedores

```bash
# RedeemService
docker run -p 8080:8080 redeem-service:latest

# CampaignService
docker run -p 8081:8080 campaign-service:latest

# CouponGenerator
docker run -e AMOUNT=1000 -e PREFIX=DEMO -e CAMPAIGN_ID=demo-campaign coupon-generator:latest
```

## Pruebas de API

### Canjear cupón
```bash
curl -X POST http://localhost:8080/api/redeem `
  -H "Content-Type: application/json" `
  -d '{"couponCode":"CUPON10OFF","userId":"user-12345"}'
```

### Consultar estado de cupón
```bash
curl http://localhost:8080/api/coupon/CUPON10OFF
```

### Solicitar generación masiva
```bash
curl -X POST http://localhost:8081/api/campaigns/CAMPAIGN-2025-BlackFriday/generate `
  -H "Content-Type: application/json" `
  -d '{"amount":50000,"prefix":"BF25","expiration":"2025-12-31T23:59:59Z"}'
```

## Despliegue en Azure

Las imágenes Docker se publican en **Azure Container Registry (ACR)**:

```bash
# Tag y push a ACR
docker tag redeem-service:latest <acr-name>.azurecr.io/redeem-service:latest
docker push <acr-name>.azurecr.io/redeem-service:latest

docker tag campaign-service:latest <acr-name>.azurecr.io/campaign-service:latest
docker push <acr-name>.azurecr.io/campaign-service:latest

docker tag coupon-generator:latest <acr-name>.azurecr.io/coupon-generator:latest
docker push <acr-name>.azurecr.io/coupon-generator:latest
```

## Integración

- **API Management (APIM)**: Enruta tráfico hacia los servicios en AKS
- **AKS**: Orquesta RedeemService y CampaignService
- **ACI**: Ejecuta CouponGenerator como job on-demand

## Modelos de Datos

### Coupon
```csharp
{
  "couponCode": "string",
  "campaignId": "string",
  "valid": true,
  "redeemed": false,
  "expiresAt": "2025-12-31T23:59:59Z",
  "assignedTo": "user-12345",
  "createdAt": "2025-01-01T00:00:00Z",
  "redeemedAt": null
}
```

### Campaign
```csharp
{
  "campaignId": "string",
  "name": "string",
  "description": "string",
  "startDate": "2025-01-01T00:00:00Z",
  "endDate": "2025-12-31T23:59:59Z",
  "active": true,
  "totalCoupons": 100000,
  "redeemedCoupons": 5000
}
```

## Licencia

Este proyecto es parte de un caso de estudio educativo.
