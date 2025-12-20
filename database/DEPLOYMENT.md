# Database Deployment Scripts

This folder contains SQL scripts for deploying and populating the Coupons Campaign System database.

## Files

1. **schema.sql** - Complete database schema (tables, indexes, stored procedures, views)
2. **sample-data.sql** - Sample data for testing and development
3. **deploy-local.ps1** - PowerShell script for local deployment
4. **deploy-azure.ps1** - PowerShell script for Azure SQL Database deployment

## Architecture Decision: Single Database

**Original Infrastructure:** 2 databases (coupons-db, campaigns-db)  
**Current Schema:** 1 unified database (coupons-db)

### Why Single Database?

1. **Transactional Consistency:** Campaigns and coupons are tightly coupled (FK constraints)
2. **Simplified Deployment:** One schema, one connection string
3. **Better Performance:** No cross-database queries
4. **Cost Optimization:** Single database reduces Azure SQL costs

### Migration Path

If you want to keep 2 databases (optional):

```sql
-- coupons-db: Coupons, RedemptionHistory, UserRedemptions tables
-- campaigns-db: Campaigns, GenerationRequests tables
```

Use the infrastructure as-is, or consolidate to `coupons-db` only (recommended).

## Local Deployment (SQL Server)

### Prerequisites

- SQL Server 2019+ or SQL Server LocalDB
- PowerShell 5.1+
- SqlServer PowerShell module

### Install SqlServer Module

```powershell
Install-Module -Name SqlServer -Scope CurrentUser -Force
```

### Deploy Schema + Sample Data

```powershell
.\deploy-local.ps1 -ServerInstance "localhost" -DatabaseName "CouponsDb" -CreateDatabase
```

### Deploy Schema Only

```powershell
.\deploy-local.ps1 -ServerInstance "localhost" -DatabaseName "CouponsDb" -SchemaOnly
```

## Azure SQL Database Deployment

### Prerequisites

- Azure CLI installed and authenticated
- Access to Azure SQL Server
- Firewall rules configured (allow your IP)

### Get Connection Info from Terraform

```powershell
cd ..\..\coupons-infrastructure-terraform\environments\production
terraform output sql_server_fqdn
terraform output sql_admin_username
terraform output -raw sql_admin_password  # Copy this
```

### Deploy to Azure

```powershell
.\deploy-azure.ps1 `
    -ServerName "coupons-sql-xxxxxxx.database.windows.net" `
    -DatabaseName "coupons-db" `
    -Username "sqladmin" `
    -Password "YourSecurePassword"
```

### Deploy from Key Vault (Automated)

```powershell
# Get credentials from Key Vault
$kvName = "coupons-kv-production"
$serverFqdn = az keyvault secret show --vault-name $kvName --name sql-server-fqdn --query value -o tsv
$username = "sqladmin"
$password = az keyvault secret show --vault-name $kvName --name sql-admin-password --query value -o tsv

.\deploy-azure.ps1 -ServerName $serverFqdn -DatabaseName "coupons-db" -Username $username -Password $password
```

## Manual Deployment

### Using Azure Data Studio / SSMS

1. Connect to Azure SQL Server
2. Select database `coupons-db`
3. Execute `schema.sql`
4. Execute `sample-data.sql`

### Using sqlcmd

```powershell
sqlcmd -S coupons-sql-xxxxxxx.database.windows.net `
       -d coupons-db `
       -U sqladmin `
       -P YourPassword `
       -i schema.sql

sqlcmd -S coupons-sql-xxxxxxx.database.windows.net `
       -d coupons-db `
       -U sqladmin `
       -P YourPassword `
       -i sample-data.sql
```

## Sample Data Overview

After running `sample-data.sql`:

- **5 Campaigns** (4 active, 1 inactive)
- **105 Coupons** across all campaigns
  - 50 Black Friday coupons
  - 30 Cyber Monday coupons
  - 20 New Year coupons
  - 5 Welcome coupons (assigned to specific users)
- **4 Successful redemptions**
- **3 Failed redemption attempts** (for testing error scenarios)
- **5 Generation requests** (4 completed, 1 pending)

## Verification Queries

```sql
-- Check campaigns
SELECT * FROM Campaigns;

-- Check active campaigns
SELECT * FROM vw_ActiveCampaigns;

-- Check coupon statistics
SELECT * FROM vw_RedemptionStats;

-- Check redemption history
SELECT TOP 10 * FROM RedemptionHistory ORDER BY AttemptedAt DESC;

-- Test coupon lookup
EXEC sp_GetCouponDetails @CouponCode = 'BF25-00001';

-- Test coupon redemption
DECLARE @Success BIT, @Message NVARCHAR(500), @CampaignId NVARCHAR(100);
EXEC sp_RedeemCoupon 
    @CouponCode = 'BF25-00003',
    @UserId = 'user-test-100',
    @Success = @Success OUTPUT,
    @Message = @Message OUTPUT,
    @CampaignId = @CampaignId OUTPUT;
SELECT @Success AS Success, @Message AS Message, @CampaignId AS CampaignId;
```

## Troubleshooting

### Error: Cannot connect to server

- Check firewall rules in Azure Portal
- Add your client IP: `az sql server firewall-rule create --resource-group <rg> --server <server> --name AllowMyIP --start-ip-address <your-ip> --end-ip-address <your-ip>`

### Error: Login failed for user

- Verify username/password
- Check if Azure AD authentication is required
- Ensure database exists

### Error: Object already exists

- Drop and recreate database, or
- Use `DROP TABLE IF EXISTS` manually before running schema.sql

## Next Steps

1. Deploy schema to Azure SQL Database
2. Configure connection strings in microservices
3. Test API endpoints with sample data
4. Set up automated backups and monitoring
5. Configure geo-replication for DR

## Production Checklist

- [ ] Schema deployed to production database
- [ ] Sample data removed (or kept for demo purposes)
- [ ] Connection strings stored in Key Vault
- [ ] Firewall rules configured (allow AKS, App Service)
- [ ] Managed Identity permissions configured
- [ ] Backups scheduled and tested
- [ ] Monitoring and alerts configured
- [ ] Performance baseline established
