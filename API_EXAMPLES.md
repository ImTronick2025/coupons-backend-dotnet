# API Request Examples - Coupons Backend

Esta colección contiene ejemplos de todas las peticiones API disponibles en los microservicios del backend.

## Información de Conexión

- **RedeemService (Local)**: `http://localhost:5210`
- **CampaignService (Local)**: `http://localhost:5277`
- **RedeemService (Producción)**: `https://<APIM_URL>/redeem`
- **CampaignService (Producción)**: `https://<APIM_URL>/campaigns`

---

## 1. Health Checks

### 1.1 Health Check - RedeemService

**Request:**
```http
GET http://localhost:5210/api/health
```

**Response (200 OK):**
```json
{
  "status": "healthy",
  "service": "redeem-service"
}
```

---

### 1.2 Health Check - CampaignService

**Request:**
```http
GET http://localhost:5277/api/campaigns/health
```

**Response (200 OK):**
```json
{
  "status": "healthy",
  "service": "campaign-service"
}
```

---

## 2. Consultar Estado de Cupón

### 2.1 Cupón Válido (Exitoso)

**Request:**
```http
GET http://localhost:5210/api/coupon/CUPON10OFF
```

**Response (200 OK):**
```json
{
  "couponCode": "CUPON10OFF",
  "valid": true,
  "redeemed": false,
  "expiresAt": "2025-12-31T23:59:59Z",
  "campaignId": "CAMPAIGN-2025-BlackFriday",
  "assignedTo": null
}
```

---

### 2.2 Cupón Canjeado

**Request:**
```http
GET http://localhost:5210/api/coupon/CUPON10OFF
```

**Response (200 OK):**
```json
{
  "couponCode": "CUPON10OFF",
  "valid": true,
  "redeemed": true,
  "expiresAt": "2025-12-31T23:59:59Z",
  "campaignId": "CAMPAIGN-2025-BlackFriday",
  "assignedTo": "user-12345"
}
```

---

### 2.3 Cupón Inexistente (Error)

**Request:**
```http
GET http://localhost:5210/api/coupon/NOEXISTE123
```

**Response (404 Not Found):**
```json
{
  "error": "COUPON_NOT_FOUND",
  "message": "El cupón no existe."
}
```

---

## 3. Canjear Cupón

### 3.1 Canje Exitoso

**Request:**
```http
POST http://localhost:5210/api/redeem
Content-Type: application/json

{
  "couponCode": "CUPON10OFF",
  "userId": "user-12345"
}
```

**Response (200 OK):**
```json
{
  "redeemed": true,
  "couponCode": "CUPON10OFF",
  "message": "Cupón canjeado exitosamente",
  "campaignId": "CAMPAIGN-2025-BlackFriday"
}
```

---

### 3.2 Cupón Ya Canjeado (Error)

**Request:**
```http
POST http://localhost:5210/api/redeem
Content-Type: application/json

{
  "couponCode": "CUPON10OFF",
  "userId": "user-99999"
}
```

**Response (400 Bad Request):**
```json
{
  "error": "REDEEM_FAILED",
  "message": "El cupón ya ha sido canjeado."
}
```

---

### 3.3 Cupón Inexistente (Error)

**Request:**
```http
POST http://localhost:5210/api/redeem
Content-Type: application/json

{
  "couponCode": "NOEXISTE999",
  "userId": "user-12345"
}
```

**Response (400 Bad Request):**
```json
{
  "error": "REDEEM_FAILED",
  "message": "El cupón ingresado no existe."
}
```

---

### 3.4 Usuario Ya Canjeó Cupón de Esta Campaña (Error)

**Request:**
```http
POST http://localhost:5210/api/redeem
Content-Type: application/json

{
  "couponCode": "OTRO-CUPON-BLACKFRIDAY",
  "userId": "user-12345"
}
```

**Response (400 Bad Request):**
```json
{
  "error": "REDEEM_FAILED",
  "message": "Ya has canjeado un cupón de esta campaña."
}
```

---

## 4. Generación Masiva de Cupones

### 4.1 Solicitud de Generación (Exitoso)

**Request:**
```http
POST http://localhost:5277/api/campaigns/CAMPAIGN-2025-BlackFriday/generate
Content-Type: application/json

{
  "amount": 50000,
  "prefix": "BF25",
  "expiration": "2025-12-31T23:59:59Z"
}
```

**Response (202 Accepted):**
```json
{
  "requestId": "gen-req-abc123def456",
  "amount": 50000,
  "campaignId": "CAMPAIGN-2025-BlackFriday",
  "status": "pending"
}
```

---

### 4.2 Generación con Cantidad Pequeña

**Request:**
```http
POST http://localhost:5277/api/campaigns/CAMPAIGN-2025-Demo/generate
Content-Type: application/json

{
  "amount": 1000,
  "prefix": "DEMO",
  "expiration": "2025-06-30T23:59:59Z"
}
```

**Response (202 Accepted):**
```json
{
  "requestId": "gen-req-xyz789ghi012",
  "amount": 1000,
  "campaignId": "CAMPAIGN-2025-Demo",
  "status": "pending"
}
```

---

### 4.3 Validación de Cantidad (Error - Fuera de Rango)

**Request:**
```http
POST http://localhost:5277/api/campaigns/CAMPAIGN-2025-Test/generate
Content-Type: application/json

{
  "amount": 2000000,
  "prefix": "TEST"
}
```

**Response (400 Bad Request):**
```json
{
  "type": "https://tools.ietf.org/html/rfc9110#section-15.5.1",
  "title": "One or more validation errors occurred.",
  "status": 400,
  "errors": {
    "amount": [
      "The field amount must be between 1 and 1000000."
    ]
  }
}
```

---

## 5. Ejemplos de Uso con cURL

### Consultar Cupón
```bash
curl -X GET "http://localhost:5210/api/coupon/CUPON10OFF"
```

### Canjear Cupón
```bash
curl -X POST "http://localhost:5210/api/redeem" \
  -H "Content-Type: application/json" \
  -d '{
    "couponCode": "CUPON10OFF",
    "userId": "user-12345"
  }'
```

### Solicitar Generación Masiva
```bash
curl -X POST "http://localhost:5277/api/campaigns/CAMPAIGN-2025-BlackFriday/generate" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 50000,
    "prefix": "BF25",
    "expiration": "2025-12-31T23:59:59Z"
  }'
```

---

## 6. Ejemplos de Uso con PowerShell

### Consultar Cupón
```powershell
Invoke-RestMethod -Uri "http://localhost:5210/api/coupon/CUPON10OFF" -Method Get
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
    amount = 50000
    prefix = "BF25"
    expiration = "2025-12-31T23:59:59Z"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost:5277/api/campaigns/CAMPAIGN-2025-BlackFriday/generate" `
    -Method Post `
    -Body $body `
    -ContentType "application/json"
```

---

## 7. Ejemplos con JavaScript (Fetch API)

### Consultar Cupón
```javascript
fetch('http://localhost:5210/api/coupon/CUPON10OFF')
  .then(response => response.json())
  .then(data => console.log(data));
```

### Canjear Cupón
```javascript
fetch('http://localhost:5210/api/redeem', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    couponCode: 'CUPON10OFF',
    userId: 'user-12345'
  })
})
  .then(response => response.json())
  .then(data => console.log(data));
```

### Solicitar Generación Masiva
```javascript
fetch('http://localhost:5277/api/campaigns/CAMPAIGN-2025-BlackFriday/generate', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    amount: 50000,
    prefix: 'BF25',
    expiration: '2025-12-31T23:59:59Z'
  })
})
  .then(response => response.json())
  .then(data => console.log(data));
```

---

## 8. Cupones de Prueba Disponibles

| Código | Campaña | Expira | Estado Inicial |
|--------|---------|--------|----------------|
| `CUPON10OFF` | CAMPAIGN-2025-BlackFriday | 2025-12-31 | Válido, No canjeado |
| `DEMO50` | CAMPAIGN-2025-Demo | 2025-12-31 | Válido, No canjeado |

**Nota**: Los cupones se resetean cada vez que se reinician los servicios (almacenamiento en memoria).

---

## 9. Códigos de Estado HTTP

| Código | Significado | Cuándo Ocurre |
|--------|-------------|---------------|
| 200 OK | Éxito | Canje exitoso, consulta exitosa |
| 202 Accepted | Aceptado | Solicitud de generación aceptada |
| 400 Bad Request | Error validación | Cupón inválido, ya canjeado, límite excedido |
| 404 Not Found | No encontrado | Cupón no existe |
| 429 Too Many Requests | Límite excedido | Rate limiting (APIM) |
| 500 Internal Server Error | Error servidor | Error interno |

---

## 10. Headers Recomendados (Producción)

```http
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json
x-api-version: 1.0
Accept: application/json
```

**Nota**: En desarrollo local, la autenticación no está habilitada. En producción (APIM), se requiere JWT.

---

## 11. Variables de Entorno (Generador)

Para ejecutar el generador de cupones localmente:

```bash
AMOUNT=1000
PREFIX=TEST
CAMPAIGN_ID=test-campaign
```

Ejecutar:
```bash
dotnet run
```

Output esperado:
```
=== Coupon Generator Job (ACI) ===
Campaign ID: test-campaign
Prefix: TEST
Amount: 1000
Starting generation at 2025-12-19T20:30:00.000Z
Generation completed at 2025-12-19T20:30:01.234Z
Total generated: 1,000
Duplicates avoided: 0
Sample coupons:
  - TEST-A1B2C3D4E5F6-AB12
  - TEST-F6E5D4C3B2A1-CD34
  ...
Job completed successfully
```
