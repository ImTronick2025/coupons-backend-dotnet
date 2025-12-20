# Database Schema - Coupons Campaign System

## Overview
Este esquema de base de datos soporta el sistema de cupones promocionales implementado en Azure SQL Database.

## Tablas Principales

### 1. Campaigns
Almacena las campañas promocionales activas e históricas.
- **Primary Key:** CampaignId
- **Características:**
  - Control de fechas de vigencia (StartDate, EndDate)
  - Límites de redención por usuario y totales
  - Descuentos por porcentaje o monto fijo
  - Estado de activación (IsActive)

### 2. Coupons
Almacena códigos de cupones individuales.
- **Primary Key:** CouponId (Identity)
- **Unique Key:** CouponCode
- **Foreign Key:** CampaignId → Campaigns
- **Características:**
  - Estado de redención (IsRedeemed)
  - Asignación opcional a usuario (AssignedTo)
  - Fecha de expiración individual
  - Trazabilidad de generación en lotes (GenerationBatchId)

### 3. RedemptionHistory
Auditoría completa de intentos de canje (exitosos y fallidos).
- **Primary Key:** RedemptionId (Identity)
- **Características:**
  - Registro de IP y User-Agent para análisis de fraude
  - Razones de fallo detalladas
  - Timestamp UTC de cada intento

### 4. GenerationRequests
Seguimiento de solicitudes de generación masiva de cupones.
- **Primary Key:** RequestId
- **Foreign Key:** CampaignId → Campaigns
- **Características:**
  - Estado del proceso (pending, running, completed, failed)
  - Cantidad solicitada vs generada
  - Trazabilidad de quién solicitó y cuándo

### 5. UserRedemptions
Control de redenciones por usuario por campaña (anti-fraude).
- **Primary Key:** UserRedemptionId (Identity)
- **Unique Key:** (UserId, CampaignId)
- **Foreign Key:** CampaignId → Campaigns
- **Características:**
  - Contador de redenciones por usuario
  - Última fecha de redención

## Stored Procedures

### sp_RedeemCoupon
Ejecuta el canje de un cupón con validaciones completas:
- Existencia del cupón
- Estado de campaña activa
- Vigencia del cupón
- Límites de redención (usuario y totales)
- Asignación de usuario
- Registro de auditoría completo

**Parámetros:**
- @CouponCode (input)
- @UserId (input)
- @IpAddress (input, opcional)
- @UserAgent (input, opcional)
- @Success (output)
- @Message (output)
- @CampaignId (output)

### sp_GetCouponDetails
Obtiene detalles completos de un cupón incluyendo validación en tiempo real.

### sp_CreateGenerationRequest
Crea una nueva solicitud de generación masiva de cupones.

### sp_UpdateGenerationRequest
Actualiza el estado de una solicitud de generación (usado por ACI job).

### sp_BulkInsertCoupons
Inserción masiva de cupones generados (optimizada para grandes volúmenes).
- **Entrada:** JSON con array de cupones
- **Transaccional:** rollback completo en caso de error

## Views

### vw_ActiveCampaigns
Campañas actualmente vigentes con porcentaje de utilización.

### vw_RedemptionStats
Estadísticas de redención por campaña (total, canjeados, disponibles, expirados).

## Índices

Todos los índices están optimizados para:
- Búsqueda rápida por código de cupón
- Consultas por usuario
- Consultas por campaña
- Filtros por fecha
- Análisis de estado de redención

## Estrategia de Deployment

1. Ejecutar `schema.sql` en Azure SQL Database
2. Verificar creación de tablas, SPs y vistas
3. Configurar Connection String en appsettings de microservicios .NET 8
4. Ejecutar migraciones de datos si hay datos legacy

## Consideraciones de Performance

- **Particionamiento:** Considerar particionamiento por CampaignId si se espera >10M cupones
- **Archivado:** Mover RedemptionHistory antigua a tabla de archivo cada trimestre
- **Índices:** Monitorear fragmentación y ejecutar REBUILD mensual
- **Estadísticas:** Actualizar estadísticas después de generaciones masivas

## Seguridad

- **Acceso:** Microservicios usan identity con permisos mínimos (EXECUTE en SPs, no acceso directo a tablas)
- **Encriptación:** Always Encrypted para datos sensibles si es requerido
- **Auditoría:** Azure SQL Auditing habilitado para compliance

## Conexión desde .NET 8

```csharp
services.AddDbContext<CouponsDbContext>(options =>
    options.UseSqlServer(
        Configuration.GetConnectionString("CouponsDatabase"),
        sqlOptions => {
            sqlOptions.EnableRetryOnFailure(
                maxRetryCount: 5,
                maxRetryDelay: TimeSpan.FromSeconds(30),
                errorNumbersToAdd: null);
        }
    ));
```

## Respaldo y Recuperación

- **Backup automático:** Azure SQL Database (punto en tiempo últimos 7-35 días)
- **Geo-replicación:** Configurar réplica en región secundaria para DR
- **Pruebas de restore:** Ejecutar trimestralmente
