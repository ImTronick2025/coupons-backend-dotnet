# Quick Reference - Database Commands

## 🚀 Quick Start

### Deploy to Azure SQL (First Time)
```powershell
cd D:\CLOUDSOLUTIONS\cupones\coupons-backend-dotnet\database

# Deploy schema + sample data
.\deploy-azure.ps1 `
    -ServerName "coupons-sql-a8cb1a4c.database.windows.net" `
    -DatabaseName "coupons-db" `
    -Username "sqladmin" `
    -Password $(az keyvault secret show --vault-name coupons-kv-production --name sql-admin-password --query value -o tsv)
```

### Deploy Locally (SQL Server)
```powershell
.\deploy-local.ps1 -ServerInstance "localhost" -DatabaseName "CouponsDb" -CreateDatabase
```

### Verify Deployment
```powershell
.\verify-azure.ps1
```

---

## 🔑 Get Connection Info

### From Terraform
```powershell
cd ..\..\coupons-infrastructure-terraform\environments\production

terraform output sql_server_fqdn
# Output: coupons-sql-a8cb1a4c.database.windows.net

terraform output coupons_db_name
# Output: coupons-db

terraform output sql_admin_username
# Output: sqladmin (sensitive)
```

### From Key Vault
```powershell
# Get password
az keyvault secret show --vault-name coupons-kv-production --name sql-admin-password --query value -o tsv

# Get connection string
az keyvault secret show --vault-name coupons-kv-production --name coupons-db-connection-string --query value -o tsv
```

---

## 🗄️ Common SQL Queries

### Check Database Status
```sql
-- Table counts
SELECT 'Campaigns' AS TableName, COUNT(*) AS Records FROM Campaigns
UNION ALL
SELECT 'Coupons', COUNT(*) FROM Coupons
UNION ALL
SELECT 'RedemptionHistory', COUNT(*) FROM RedemptionHistory;

-- Active campaigns
SELECT * FROM vw_ActiveCampaigns;

-- Coupon statistics
SELECT * FROM vw_RedemptionStats;
```

### Test Coupon Redemption
```sql
DECLARE @Success BIT, @Message NVARCHAR(500), @CampaignId NVARCHAR(100);

EXEC sp_RedeemCoupon 
    @CouponCode = 'BF25-00005',
    @UserId = 'test-user-001',
    @IpAddress = '192.168.1.100',
    @UserAgent = 'TestClient/1.0',
    @Success = @Success OUTPUT,
    @Message = @Message OUTPUT,
    @CampaignId = @CampaignId OUTPUT;

SELECT @Success AS Success, @Message AS Message, @CampaignId AS CampaignId;
```

### Get Coupon Details
```sql
EXEC sp_GetCouponDetails @CouponCode = 'WELCOME-USER001';
```

### Check User Redemptions
```sql
SELECT * FROM UserRedemptions WHERE UserId = 'user-001';
```

### Recent Redemption Attempts
```sql
SELECT TOP 20 * FROM RedemptionHistory ORDER BY AttemptedAt DESC;
```

---

## 🔧 Maintenance Commands

### Add Firewall Rule
```powershell
# Get your IP
$myIp = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content.Trim()

# Add rule
az sql server firewall-rule create `
    --resource-group "coupons-production-rg" `
    --server "coupons-sql-a8cb1a4c" `
    --name "AllowMyIP-$(Get-Date -Format 'yyyyMMdd')" `
    --start-ip-address $myIp `
    --end-ip-address $myIp
```

### List Firewall Rules
```powershell
az sql server firewall-rule list `
    --resource-group "coupons-production-rg" `
    --server "coupons-sql-a8cb1a4c" `
    --output table
```

### Update Statistics (after bulk insert)
```sql
EXEC sp_updatestats;
```

### Rebuild Indexes (monthly)
```sql
ALTER INDEX ALL ON Coupons REBUILD;
ALTER INDEX ALL ON Campaigns REBUILD;
```

---

## 🧪 Testing Scenarios

### Scenario 1: Valid Redemption
```sql
-- Should succeed
EXEC sp_RedeemCoupon @CouponCode = 'NY26-00001', @UserId = 'new-user-001';
```

### Scenario 2: Already Redeemed
```sql
-- Should fail: "Coupon already redeemed"
EXEC sp_RedeemCoupon @CouponCode = 'WELCOME-USER001', @UserId = 'any-user';
```

### Scenario 3: Invalid Coupon
```sql
-- Should fail: "Coupon not found"
EXEC sp_RedeemCoupon @CouponCode = 'INVALID-XYZ', @UserId = 'test-user';
```

### Scenario 4: Expired Coupon
```sql
-- Should fail: "Coupon expired"
EXEC sp_RedeemCoupon @CouponCode = 'BF25-00001', @UserId = 'test-user';
```

### Scenario 5: User Limit Exceeded
```sql
-- First redemption: success
EXEC sp_RedeemCoupon @CouponCode = 'NY26-00001', @UserId = 'user-limit-test';

-- Second redemption (campaign allows max 2): success
EXEC sp_RedeemCoupon @CouponCode = 'NY26-00002', @UserId = 'user-limit-test';

-- Third redemption: should fail "User redemption limit reached"
EXEC sp_RedeemCoupon @CouponCode = 'NY26-00003', @UserId = 'user-limit-test';
```

### Scenario 6: Wrong User for Assigned Coupon
```sql
-- Should fail: "Coupon assigned to different user"
EXEC sp_RedeemCoupon @CouponCode = 'WELCOME-USER002', @UserId = 'hacker-user';

-- Should succeed
EXEC sp_RedeemCoupon @CouponCode = 'WELCOME-USER002', @UserId = 'user-002';
```

---

## 📊 Analytics Queries

### Redemption Rate by Campaign
```sql
SELECT 
    c.Name AS Campaign,
    COUNT(cp.CouponId) AS TotalCoupons,
    SUM(CASE WHEN cp.IsRedeemed = 1 THEN 1 ELSE 0 END) AS Redeemed,
    CAST(SUM(CASE WHEN cp.IsRedeemed = 1 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(cp.CouponId) * 100 AS RedemptionRate
FROM Campaigns c
LEFT JOIN Coupons cp ON c.CampaignId = cp.CampaignId
GROUP BY c.Name
ORDER BY RedemptionRate DESC;
```

### Top Users by Redemptions
```sql
SELECT TOP 10
    UserId,
    COUNT(DISTINCT CampaignId) AS CampaignsUsed,
    SUM(RedemptionCount) AS TotalRedemptions,
    MAX(LastRedeemedAt) AS LastRedemption
FROM UserRedemptions
GROUP BY UserId
ORDER BY TotalRedemptions DESC;
```

### Failed Redemption Patterns
```sql
SELECT 
    FailureReason,
    COUNT(*) AS Occurrences,
    COUNT(DISTINCT UserId) AS AffectedUsers
FROM RedemptionHistory
WHERE Success = 0
GROUP BY FailureReason
ORDER BY Occurrences DESC;
```

### Generation Performance
```sql
SELECT 
    RequestId,
    RequestedAmount,
    GeneratedAmount,
    DATEDIFF(SECOND, StartedAt, CompletedAt) AS DurationSeconds,
    CAST(GeneratedAmount AS FLOAT) / DATEDIFF(SECOND, StartedAt, CompletedAt) AS CouponsPerSecond
FROM GenerationRequests
WHERE Status = 'completed'
ORDER BY CreatedAt DESC;
```

---

## 🔐 .NET Connection Examples

### appsettings.json (with Key Vault)
```json
{
  "ConnectionStrings": {
    "CouponsDatabase": "@Microsoft.KeyVault(SecretUri=https://coupons-kv-production.vault.azure.net/secrets/coupons-db-connection-string/)"
  }
}
```

### Program.cs (EF Core)
```csharp
builder.Services.AddDbContext<CouponsDbContext>(options =>
    options.UseSqlServer(
        builder.Configuration.GetConnectionString("CouponsDatabase"),
        sqlOptions => {
            sqlOptions.EnableRetryOnFailure(
                maxRetryCount: 5,
                maxRetryDelay: TimeSpan.FromSeconds(30),
                errorNumbersToAdd: null);
            sqlOptions.CommandTimeout(60);
        }
    ));
```

### Calling Stored Procedure
```csharp
var couponCodeParam = new SqlParameter("@CouponCode", "BF25-00001");
var userIdParam = new SqlParameter("@UserId", "user-001");
var successParam = new SqlParameter("@Success", SqlDbType.Bit) { Direction = ParameterDirection.Output };
var messageParam = new SqlParameter("@Message", SqlDbType.NVarChar, 500) { Direction = ParameterDirection.Output };
var campaignIdParam = new SqlParameter("@CampaignId", SqlDbType.NVarChar, 100) { Direction = ParameterDirection.Output };

await context.Database.ExecuteSqlRawAsync(
    "EXEC sp_RedeemCoupon @CouponCode, @UserId, @IpAddress, @UserAgent, @Success OUTPUT, @Message OUTPUT, @CampaignId OUTPUT",
    couponCodeParam, userIdParam, ipParam, userAgentParam, successParam, messageParam, campaignIdParam
);

bool success = (bool)successParam.Value;
string message = messageParam.Value.ToString();
string campaignId = campaignIdParam.Value.ToString();
```

---

## 📁 File Locations

### Database Scripts
```
D:\CLOUDSOLUTIONS\cupones\coupons-backend-dotnet\database\
├── schema.sql                 # Database schema
├── sample-data.sql           # Sample test data
├── deploy-azure.ps1          # Azure deployment script
├── deploy-local.ps1          # Local deployment script
├── verify-azure.ps1          # Verification script
├── verification-queries.sql  # Manual verification
├── README.md                 # Database documentation
├── DEPLOYMENT.md            # Deployment guide
├── DATABASE_SUMMARY.md      # Complete summary
├── SCHEMA_DIAGRAM.md        # ER diagrams & flows
└── QUICK_REFERENCE.md       # This file
```

### Terraform
```
D:\CLOUDSOLUTIONS\cupones\coupons-infrastructure-terraform\
└── environments\production\
    ├── main.tf              # Infrastructure definition
    ├── variables.tf         # Variable definitions
    └── outputs.tf          # Output values
```

---

## 🆘 Troubleshooting

### Cannot connect
```powershell
# Check firewall
az sql server firewall-rule list --resource-group coupons-production-rg --server coupons-sql-a8cb1a4c

# Add your IP
$myIp = (Invoke-WebRequest -Uri "https://api.ipify.org").Content.Trim()
az sql server firewall-rule create --resource-group coupons-production-rg --server coupons-sql-a8cb1a4c --name AllowMe --start-ip-address $myIp --end-ip-address $myIp
```

### Login failed
```powershell
# Verify password
az keyvault secret show --vault-name coupons-kv-production --name sql-admin-password --query value -o tsv
```

### Slow queries
```sql
-- Check execution plan
SET STATISTICS IO ON;
SET STATISTICS TIME ON;

-- Your query here
SELECT * FROM vw_RedemptionStats;

-- Rebuild indexes
ALTER INDEX ALL ON Coupons REBUILD;
```

---

## 📞 Support

For issues or questions:
1. Check `DATABASE_SUMMARY.md` for deployment status
2. Review `DEPLOYMENT.md` for step-by-step guide
3. See `SCHEMA_DIAGRAM.md` for architecture
4. Consult `README.md` for detailed documentation

**Database Status:** ✅ Deployed and Verified  
**Last Updated:** December 19, 2025
