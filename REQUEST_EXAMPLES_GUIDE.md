# Guía de Uso de Ejemplos de API

Este repositorio incluye varios formatos de ejemplos para facilitar las pruebas de la API.

## 📁 Archivos Disponibles

### 1. **API_EXAMPLES.md**
Documentación completa con ejemplos de todas las peticiones en múltiples formatos:
- HTTP Raw
- cURL
- PowerShell
- JavaScript (Fetch API)
- Respuestas de ejemplo

**Uso**: Consulta rápida y documentación de referencia.

---

### 2. **requests.http**
Archivo REST Client para VS Code / Visual Studio / IntelliJ IDEA.

**Cómo usar:**

#### En Visual Studio Code:
1. Instalar extensión: [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)
2. Abrir archivo `requests.http`
3. Click en "Send Request" sobre cada petición
4. Ver respuesta en panel lateral

#### En Visual Studio:
1. Abrir archivo `requests.http`
2. Los endpoints aparecerán con opción "Send Request"

#### En IntelliJ IDEA / Rider:
1. Soporte nativo para archivos `.http`
2. Abrir archivo y ejecutar peticiones directamente

**Ventajas:**
- ✅ No requiere Postman
- ✅ Versionado con Git
- ✅ Ejecutar directamente desde el IDE
- ✅ Variables de entorno incluidas

---

### 3. **Coupons_Backend_API.postman_collection.json**
Colección de Postman con todas las peticiones organizadas.

**Cómo usar:**

1. **Importar en Postman:**
   - Abrir Postman
   - Click en "Import"
   - Seleccionar archivo `Coupons_Backend_API.postman_collection.json`
   - Click "Import"

2. **Configurar Variables:**
   - Las URLs ya están configuradas para desarrollo local:
     - `redeemServiceUrl`: http://localhost:5210
     - `campaignServiceUrl`: http://localhost:5277
   
3. **Para producción:**
   - Crear un Environment nuevo
   - Agregar variables con URLs de producción

**Ventajas:**
- ✅ Interfaz gráfica amigable
- ✅ Tests automatizados (puede agregar)
- ✅ Compartir con equipo
- ✅ Generar documentación

---

### 4. **test-local.ps1**
Script PowerShell automatizado para ejecutar todas las pruebas.

**Cómo usar:**
```powershell
# Asegurarse que los servicios están corriendo
.\test-local.ps1
```

**Ventajas:**
- ✅ Pruebas automatizadas completas
- ✅ Validación de todos los escenarios
- ✅ Output colorizado
- ✅ No requiere herramientas adicionales

---

## 🚀 Flujo de Trabajo Recomendado

### Para Desarrollo:
1. Usar **VS Code REST Client** (`requests.http`) para pruebas rápidas
2. Ejecutar **test-local.ps1** para validación completa
3. Consultar **API_EXAMPLES.md** para documentación

### Para QA/Testing:
1. Usar **Postman** con la colección importada
2. Crear tests automatizados en Postman
3. Exportar resultados de tests

### Para Documentación:
1. Consultar **API_EXAMPLES.md**
2. Compartir con equipo frontend
3. Incluir en documentación del proyecto

---

## 📋 Ejemplos Rápidos

### Usando VS Code REST Client

1. Abrir `requests.http`
2. Ubicar la petición deseada:
   ```http
   ### Get Coupon Status - CUPON10OFF
   GET {{redeemServiceUrl}}/api/coupon/CUPON10OFF
   ```
3. Click en "Send Request"
4. Ver respuesta inmediatamente

---

### Usando Postman

1. Importar colección
2. Seleccionar "Health Check - RedeemService"
3. Click "Send"
4. Ver respuesta en panel inferior

---

### Usando cURL (desde API_EXAMPLES.md)

```bash
curl -X GET "http://localhost:5210/api/coupon/CUPON10OFF"
```

---

### Usando PowerShell (desde API_EXAMPLES.md)

```powershell
Invoke-RestMethod -Uri "http://localhost:5210/api/coupon/CUPON10OFF" -Method Get
```

---

## 🔧 Variables de Entorno

### Local (por defecto):
- `redeemServiceUrl`: http://localhost:5210
- `campaignServiceUrl`: http://localhost:5277

### Producción (configurar):
- `redeemServiceUrl`: https://api.tudominio.com/redeem
- `campaignServiceUrl`: https://api.tudominio.com/campaigns

---

## 📦 Cupones Demo Incluidos

Para pruebas locales, los servicios incluyen:

| Código | Campaña | Estado |
|--------|---------|--------|
| `CUPON10OFF` | CAMPAIGN-2025-BlackFriday | Válido |
| `DEMO50` | CAMPAIGN-2025-Demo | Válido |

**Nota**: Se resetean al reiniciar servicios (in-memory).

---

## 🎯 Escenarios de Prueba Pre-configurados

### En `requests.http`:

1. **Complete User Journey**
   - Check coupon → Redeem → Verify → Try again

2. **Campaign Limit Test**
   - Redeem first → Try second from same campaign

### En Postman:

Colecciones organizadas por:
- Health Checks
- Coupon Status
- Redeem Coupon
- Generate Coupons

---

## 💡 Tips

### Para requests.http:
- Usa `###` para separar peticiones
- `@variable = valor` para variables
- `Ctrl + Alt + E` para ejecutar (VS Code)

### Para Postman:
- Usa Environments para dev/staging/prod
- Agrega Tests en la pestaña "Tests"
- Usa `pm.test()` para assertions

### Para PowerShell:
- Usa `-Verbose` para ver detalles
- Captura respuesta: `$response = Invoke-RestMethod...`
- Formatear JSON: `| ConvertTo-Json`

---

## 🐛 Troubleshooting

### "Connection refused"
✅ Verificar que los servicios estén corriendo:
```powershell
# Terminal 1
cd src\RedeemService\RedeemService
dotnet run

# Terminal 2
cd src\CampaignService\CampaignService
dotnet run
```

### "404 Not Found" en health check
✅ Usar la ruta correcta:
- RedeemService: `/api/health`
- CampaignService: `/api/campaigns/health`

### "400 Bad Request"
✅ Verificar que el JSON esté bien formado
✅ Verificar que el cupón no esté ya canjeado

---

## 📚 Recursos Adicionales

- [REST Client VS Code](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)
- [Postman Download](https://www.postman.com/downloads/)
- [PowerShell Invoke-RestMethod](https://docs.microsoft.com/powershell/module/microsoft.powershell.utility/invoke-restmethod)

---

**Repositorio**: https://github.com/ImTronick2025/coupons-backend-dotnet
