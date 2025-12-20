# Guía de Pruebas Locales

## Prerequisitos

- .NET 9.0 SDK instalado
- PowerShell 7+ (opcional, pero recomendado)
- Puertos 5210 y 5277 disponibles

## Opción 1: Ejecución Manual

### Paso 1: Iniciar RedeemService

Abrir una terminal PowerShell:

```powershell
cd D:\CLOUDSOLUTIONS\cupones\coupons-backend-dotnet
cd src\RedeemService\RedeemService
$env:ASPNETCORE_URLS="http://localhost:8080"
dotnet run
```

El servicio estará disponible en: **http://localhost:5210**

### Paso 2: Iniciar CampaignService

Abrir OTRA terminal PowerShell:

```powershell
cd D:\CLOUDSOLUTIONS\cupones\coupons-backend-dotnet
cd src\CampaignService\CampaignService
$env:ASPNETCORE_URLS="http://localhost:8081"
dotnet run
```

El servicio estará disponible en: **http://localhost:5277**

### Paso 3: Ejecutar Pruebas

Abrir UNA TERCERA terminal PowerShell:

```powershell
cd D:\CLOUDSOLUTIONS\cupones\coupons-backend-dotnet
.\test-local.ps1
```

## Opción 2: Script Todo-en-Uno

Usar el script `start-local.ps1` (próximamente) que inicia ambos servicios automáticamente.

## Pruebas Individuales con cURL

### Health Check - RedeemService
```bash
curl http://localhost:5210/api/health
```

### Health Check - CampaignService
```bash
curl http://localhost:5277/api/campaigns/health
```

### Consultar Estado de Cupón
```bash
curl http://localhost:5210/api/coupon/CUPON10OFF
```

### Canjear Cupón
```powershell
$body = @{
    couponCode = "CUPON10OFF"
    userId = "user-12345"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:5210/api/redeem" `
    -Method Post `
    -Body $body `
    -ContentType "application/json"
```

### Solicitar Generación Masiva
```powershell
$body = @{
    amount = 1000
    prefix = "BF25"
    expiration = "2025-12-31T23:59:59Z"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:5277/api/campaigns/CAMPAIGN-2025-BlackFriday/generate" `
    -Method Post `
    -Body $body `
    -ContentType "application/json"
```

## Probar Generador de Cupones (ACI Job Simulator)

```powershell
cd src\CouponGenerator\CouponGenerator
$env:AMOUNT="1000"
$env:PREFIX="DEMO"
$env:CAMPAIGN_ID="demo-campaign"
dotnet run
```

## Cupones Demo Pre-cargados

El **RedeemService** incluye 2 cupones de prueba:

| Código | Campaña | Expira | Estado |
|--------|---------|--------|--------|
| `CUPON10OFF` | CAMPAIGN-2025-BlackFriday | 2025-12-31 | Válido |
| `DEMO50` | CAMPAIGN-2025-Demo | 2025-12-31 | Válido |

## Escenarios de Prueba

### ✅ Escenario 1: Canje Exitoso
1. Consultar cupón `CUPON10OFF` → Estado: válido, no canjeado
2. Canjear cupón para `user-12345` → Éxito
3. Consultar cupón nuevamente → Estado: canjeado, asignado a user-12345

### ❌ Escenario 2: Cupón Ya Canjeado
1. Canjear cupón `CUPON10OFF` para `user-12345`
2. Intentar canjear mismo cupón para `user-99999` → Error 400

### ❌ Escenario 3: Límite por Campaña
1. Canjear cupón `CUPON10OFF` (campaña BlackFriday) para `user-12345`
2. Intentar canjear otro cupón de BlackFriday para mismo usuario → Error 400

### ❌ Escenario 4: Cupón Inexistente
1. Consultar cupón `NOEXISTE123` → Error 404

### ✅ Escenario 5: Generación Masiva
1. Solicitar generación de 5000 cupones
2. Respuesta 202 Accepted con requestId
3. Estado: "pending" → "running" → "completed"

## Verificar Logs

### RedeemService
En la terminal donde corre RedeemService verás logs como:
```
info: RedeemService.Controllers.CouponsController[0]
      Redeem request for coupon CUPON10OFF by user user-12345
info: RedeemService.Controllers.CouponsController[0]
      Coupon CUPON10OFF redeemed successfully
```

### CampaignService
En la terminal donde corre CampaignService:
```
info: CampaignService.Controllers.CampaignsController[0]
      Generate request for campaign CAMPAIGN-2025-BlackFriday: 1000 coupons with prefix BF25
info: CampaignService.Services.CampaignGeneratorService[0]
      Generation request gen-req-abc123 created for campaign CAMPAIGN-2025-BlackFriday
```

## Detener Servicios

En cada terminal donde corren los servicios:
- Presionar **Ctrl+C**

## Problemas Comunes

### Puerto ya en uso
Si el puerto 5210 o 5277 está en uso:
```powershell
# Cambiar puerto en launchSettings.json o usar variable de entorno
$env:ASPNETCORE_URLS="http://localhost:OTRO_PUERTO"
```

### Error de conexión
- Verificar que ambos servicios estén corriendo
- Revisar que no haya firewall bloqueando localhost
- Usar `http://` no `https://` para pruebas locales

### Error 404 en health check
- RedeemService: `/api/health`
- CampaignService: `/api/campaigns/health` (no olvidar `/campaigns`)

## Siguiente Paso: Docker

Una vez probado localmente, probar con Docker Compose:
```bash
docker compose up --build
```

Esto iniciará ambos servicios en:
- RedeemService: http://localhost:8080
- CampaignService: http://localhost:8081
