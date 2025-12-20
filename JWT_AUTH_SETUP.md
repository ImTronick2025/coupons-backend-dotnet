# Configuración de Autenticación JWT (Opcional)

Esta guía explica cómo agregar autenticación JWT a los servicios para alinear completamente con el contrato API First.

## ⚠️ Nota Importante

La autenticación JWT **no es necesaria para desarrollo local**. Sin embargo, es **obligatoria para producción** según el contrato API First.

En producción, la autenticación se puede manejar en dos niveles:
1. **APIM (Recomendado)**: API Management valida el JWT antes de llegar al backend
2. **Backend**: Los servicios validan el JWT directamente

---

## Opción 1: Autenticación en APIM (Recomendado)

### Ventajas
- ✅ Centralizada en un solo punto
- ✅ No requiere cambios en el código backend
- ✅ Políticas reutilizables
- ✅ Mejor performance

### Configuración en APIM

```xml
<policies>
    <inbound>
        <!-- Validar JWT -->
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401">
            <openid-config url="https://<YOUR_AUTHORITY>/.well-known/openid-configuration" />
            <audiences>
                <audience>coupons-api</audience>
            </audiences>
            <required-claims>
                <claim name="scope" match="any">
                    <value>coupons.read</value>
                    <value>coupons.redeem</value>
                </claim>
            </required-claims>
        </validate-jwt>
        
        <!-- Rate Limiting -->
        <rate-limit calls="100" renewal-period="60" />
        
        <!-- CORS -->
        <cors>
            <allowed-origins>
                <origin>*</origin>
            </allowed-origins>
            <allowed-methods>
                <method>GET</method>
                <method>POST</method>
            </allowed-methods>
        </cors>
    </inbound>
</policies>
```

---

## Opción 2: Autenticación en Backend

Si prefieres validar JWT directamente en los servicios .NET:

### Paso 1: Instalar paquetes NuGet

```bash
# En ambos proyectos (RedeemService y CampaignService)
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
dotnet add package Microsoft.Identity.Web
```

### Paso 2: Actualizar appsettings.json

**RedeemService/appsettings.json:**
```json
{
  "AzureAd": {
    "Instance": "https://login.microsoftonline.com/",
    "Domain": "yourdomain.onmicrosoft.com",
    "TenantId": "your-tenant-id",
    "ClientId": "your-client-id",
    "Audience": "coupons-api"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
```

### Paso 3: Configurar JWT en Program.cs

**RedeemService/Program.cs:**
```csharp
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Identity.Web;
using RedeemService.Services;

var builder = WebApplication.CreateBuilder(args);

// Configurar autenticación JWT
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));

// O para JWT genérico (no Azure AD):
/*
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.Authority = "https://your-identity-server.com";
        options.Audience = "coupons-api";
        options.RequireHttpsMetadata = true;
        
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = "https://your-identity-server.com",
            ValidAudience = "coupons-api"
        };
    });
*/

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("RequireUserRole", policy => 
        policy.RequireRole("User", "Admin"));
    
    options.AddPolicy("RequireAdminRole", policy => 
        policy.RequireRole("Admin"));
});

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddOpenApi();

builder.Services.AddSingleton<ICouponService, CouponService>();

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseCors();
app.UseHttpsRedirection();

// ⚠️ IMPORTANTE: El orden importa
app.UseAuthentication();  // Debe ir antes de UseAuthorization
app.UseAuthorization();

app.MapControllers();

app.Run();
```

### Paso 4: Proteger endpoints con [Authorize]

**RedeemService/Controllers/CouponsController.cs:**
```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Shared.Models.DTOs;
using RedeemService.Services;

namespace RedeemService.Controllers;

[ApiController]
[Route("api")]
[Authorize] // Requiere autenticación en todos los endpoints
public class CouponsController : ControllerBase
{
    private readonly ICouponService _couponService;
    private readonly ILogger<CouponsController> _logger;

    public CouponsController(ICouponService couponService, ILogger<CouponsController> logger)
    {
        _couponService = couponService;
        _logger = logger;
    }

    [HttpPost("redeem")]
    [Authorize(Policy = "RequireUserRole")] // Admin o User
    [ProducesResponseType(typeof(RedeemResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> RedeemCoupon([FromBody] RedeemRequest request)
    {
        // Obtener userId del token JWT en vez del request
        var userIdFromToken = User.FindFirst("sub")?.Value 
                           ?? User.FindFirst("oid")?.Value
                           ?? request.UserId;

        _logger.LogInformation("Redeem request for coupon {CouponCode} by user {UserId}", 
            request.CouponCode, userIdFromToken);

        var response = await _couponService.RedeemCouponAsync(request);

        if (!response.Redeemed)
        {
            _logger.LogWarning("Redeem failed for coupon {CouponCode}: {Message}", 
                request.CouponCode, response.Message);
                
            return BadRequest(new ErrorResponse
            {
                Error = "REDEEM_FAILED",
                Message = response.Message
            });
        }

        _logger.LogInformation("Coupon {CouponCode} redeemed successfully", request.CouponCode);
        return Ok(response);
    }

    [HttpGet("coupon/{code}")]
    [Authorize(Policy = "RequireUserRole")] // Admin o User
    [ProducesResponseType(typeof(CouponStatusResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetCouponStatus(string code)
    {
        _logger.LogInformation("Status request for coupon {CouponCode}", code);

        var coupon = await _couponService.GetCouponStatusAsync(code);

        if (coupon == null)
        {
            _logger.LogWarning("Coupon {CouponCode} not found", code);
            
            return NotFound(new ErrorResponse
            {
                Error = "COUPON_NOT_FOUND",
                Message = "El cupón no existe."
            });
        }

        return Ok(coupon);
    }

    [HttpGet("health")]
    [AllowAnonymous] // Health check no requiere autenticación
    public IActionResult Health()
    {
        return Ok(new { status = "healthy", service = "redeem-service" });
    }
}
```

**CampaignService/Controllers/CampaignsController.cs:**
```csharp
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Shared.Models.DTOs;
using CampaignService.Services;

namespace CampaignService.Controllers;

[ApiController]
[Route("api/campaigns")]
[Authorize]
public class CampaignsController : ControllerBase
{
    private readonly ICampaignGeneratorService _generatorService;
    private readonly ILogger<CampaignsController> _logger;

    public CampaignsController(ICampaignGeneratorService generatorService, ILogger<CampaignsController> logger)
    {
        _generatorService = generatorService;
        _logger = logger;
    }

    [HttpPost("{id}/generate")]
    [Authorize(Policy = "RequireAdminRole")] // Solo Admin
    [ProducesResponseType(typeof(GenerateResponse), StatusCodes.Status202Accepted)]
    [ProducesResponseType(typeof(ErrorResponse), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GenerateCoupons(string id, [FromBody] GenerateRequest request)
    {
        _logger.LogInformation(
            "Generate request for campaign {CampaignId}: {Amount} coupons with prefix {Prefix}",
            id, request.Amount, request.Prefix);

        var response = await _generatorService.RequestGenerationAsync(id, request);

        _logger.LogInformation("Generation request {RequestId} accepted", response.RequestId);

        return StatusCode(StatusCodes.Status202Accepted, response);
    }

    [HttpGet("health")]
    [AllowAnonymous]
    public IActionResult Health()
    {
        return Ok(new { status = "healthy", service = "campaign-service" });
    }
}
```

---

## Probar con JWT

### Opción A: Usar token de Azure AD

```powershell
# Obtener token con Azure CLI
$token = az account get-access-token --resource <CLIENT_ID> --query accessToken -o tsv

# Probar endpoint
Invoke-RestMethod -Uri "http://localhost:5210/api/coupon/CUPON10OFF" `
    -Method Get `
    -Headers @{ Authorization = "Bearer $token" }
```

### Opción B: Generar token JWT de prueba

Usar https://jwt.io para crear un token de prueba con:
```json
{
  "sub": "user-12345",
  "role": "User",
  "aud": "coupons-api",
  "iss": "https://your-identity-server.com",
  "exp": 1735689600
}
```

---

## Deshabilitar autenticación para desarrollo local

Crear archivo `appsettings.Development.json`:

```json
{
  "DisableAuthentication": true
}
```

Y en Program.cs:
```csharp
var disableAuth = builder.Configuration.GetValue<bool>("DisableAuthentication");

if (!disableAuth)
{
    builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
        .AddJwtBearer(options => { /* ... */ });
}
```

---

## 🔐 Configuración de Roles

### Claims requeridos en JWT

```json
{
  "sub": "user-12345",           // Subject (user ID)
  "role": ["User"],              // O ["Admin"]
  "scope": "coupons.redeem",     // Scope
  "aud": "coupons-api",          // Audience
  "iss": "https://identity.com", // Issuer
  "exp": 1735689600              // Expiration
}
```

### Mapeo de políticas

- `RequireUserRole`: Pueden canjear y consultar cupones
- `RequireAdminRole`: Pueden generar cupones masivamente

---

## 📚 Referencias

- [Microsoft Identity Web](https://learn.microsoft.com/aspnet/core/security/authentication/identity-api-authorization)
- [JWT Bearer Authentication](https://learn.microsoft.com/aspnet/core/security/authentication/jwt-authn)
- [Azure AD B2C](https://learn.microsoft.com/azure/active-directory-b2c/)

---

**Estado actual**: Autenticación no implementada (desarrollo local)  
**Producción**: Implementar antes de desplegar a Azure
