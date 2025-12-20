# =============================================
# PowerShell Script: Run verification queries on Azure SQL
# =============================================

param(
    [Parameter(Mandatory=$false)]
    [string]$ServerName = "coupons-sql-a8cb1a4c.database.windows.net",
    
    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "coupons-db",
    
    [Parameter(Mandatory=$false)]
    [string]$Username = "sqladmin"
)

$ErrorActionPreference = "Stop"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Database Verification - Azure SQL" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Get password from Key Vault
Write-Host "Retrieving password from Key Vault..." -ForegroundColor Yellow
$password = az keyvault secret show --vault-name "coupons-kv-production" --name "sql-admin-password" --query value -o tsv

if (-not $password) {
    Write-Error "Failed to retrieve password from Key Vault"
    exit 1
}

# Connection string
$ConnectionString = "Server=tcp:$ServerName,1433;Initial Catalog=$DatabaseName;Persist Security Info=False;User ID=$Username;Password=$password;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

function Invoke-SqlQuery {
    param(
        [string]$Query,
        [string]$Description
    )
    
    Write-Host "-------------------------------------------" -ForegroundColor Gray
    Write-Host $Description -ForegroundColor Yellow
    Write-Host "-------------------------------------------" -ForegroundColor Gray
    
    try {
        $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $Connection.Open()
        
        $Command = $Connection.CreateCommand()
        $Command.CommandText = $Query
        $Command.CommandTimeout = 60
        
        $Adapter = New-Object System.Data.SqlClient.SqlDataAdapter($Command)
        $DataSet = New-Object System.Data.DataSet
        $Adapter.Fill($DataSet) | Out-Null
        
        $Connection.Close()
        
        if ($DataSet.Tables.Count -gt 0 -and $DataSet.Tables[0].Rows.Count -gt 0) {
            $DataSet.Tables[0] | Format-Table -AutoSize
        } else {
            Write-Host "  (No data returned)" -ForegroundColor Gray
        }
        
    } catch {
        Write-Host "  Error: $_" -ForegroundColor Red
    }
    
    Write-Host ""
}

# 1. Database Overview
Invoke-SqlQuery -Description "1. DATABASE OVERVIEW" -Query @"
SELECT 
    'Campaigns' AS TableName, 
    COUNT(*) AS TotalRecords,
    SUM(CASE WHEN IsActive = 1 THEN 1 ELSE 0 END) AS ActiveRecords
FROM Campaigns
UNION ALL
SELECT 
    'Coupons', 
    COUNT(*),
    SUM(CASE WHEN IsRedeemed = 0 AND GETUTCDATE() <= ExpiresAt THEN 1 ELSE 0 END)
FROM Coupons
UNION ALL
SELECT 
    'RedemptionHistory', 
    COUNT(*),
    SUM(CASE WHEN Success = 1 THEN 1 ELSE 0 END)
FROM RedemptionHistory
UNION ALL
SELECT 
    'GenerationRequests', 
    COUNT(*),
    SUM(CASE WHEN Status = 'completed' THEN 1 ELSE 0 END)
FROM GenerationRequests
UNION ALL
SELECT 
    'UserRedemptions', 
    COUNT(*),
    COUNT(DISTINCT UserId)
FROM UserRedemptions;
"@

# 2. Active Campaigns
Invoke-SqlQuery -Description "2. ACTIVE CAMPAIGNS" -Query "SELECT * FROM vw_ActiveCampaigns;"

# 3. Coupon Statistics
Invoke-SqlQuery -Description "3. COUPON STATISTICS BY CAMPAIGN" -Query "SELECT * FROM vw_RedemptionStats;"

# 4. Recent Redemption History
Invoke-SqlQuery -Description "4. RECENT REDEMPTION HISTORY (Last 10)" -Query @"
SELECT TOP 10
    RedemptionId,
    CouponCode,
    UserId,
    CampaignId,
    AttemptedAt,
    Success,
    FailureReason,
    IpAddress
FROM RedemptionHistory
ORDER BY AttemptedAt DESC;
"@

# 5. User Redemption Summary
Invoke-SqlQuery -Description "5. USER REDEMPTION SUMMARY" -Query @"
SELECT 
    ur.UserId,
    c.Name AS CampaignName,
    ur.RedemptionCount,
    ur.LastRedeemedAt,
    camp.MaxRedemptionsPerUser,
    CASE 
        WHEN ur.RedemptionCount >= camp.MaxRedemptionsPerUser THEN 'At Limit'
        ELSE 'Available'
    END AS Status
FROM UserRedemptions ur
INNER JOIN Campaigns camp ON ur.CampaignId = camp.CampaignId
LEFT JOIN Campaigns c ON ur.CampaignId = c.CampaignId
ORDER BY ur.LastRedeemedAt DESC;
"@

# 6. Generation Requests
Invoke-SqlQuery -Description "6. GENERATION REQUESTS STATUS" -Query @"
SELECT 
    gr.RequestId,
    c.Name AS CampaignName,
    gr.RequestedAmount,
    gr.GeneratedAmount,
    gr.Prefix,
    gr.Status,
    gr.CreatedAt,
    gr.RequestedBy
FROM GenerationRequests gr
LEFT JOIN Campaigns c ON gr.CampaignId = c.CampaignId
ORDER BY gr.CreatedAt DESC;
"@

# 7. Test Get Coupon Details
Write-Host "-------------------------------------------" -ForegroundColor Gray
Write-Host "7. TEST STORED PROCEDURE: Get Coupon Details" -ForegroundColor Yellow
Write-Host "-------------------------------------------" -ForegroundColor Gray

try {
    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $Connection.Open()
    
    $Command = $Connection.CreateCommand()
    $Command.CommandType = [System.Data.CommandType]::StoredProcedure
    $Command.CommandText = "sp_GetCouponDetails"
    $Command.Parameters.AddWithValue("@CouponCode", "BF25-00005") | Out-Null
    
    $Adapter = New-Object System.Data.SqlClient.SqlDataAdapter($Command)
    $DataSet = New-Object System.Data.DataSet
    $Adapter.Fill($DataSet) | Out-Null
    
    $Connection.Close()
    
    Write-Host "Coupon Code: BF25-00005" -ForegroundColor Cyan
    $DataSet.Tables[0] | Format-List
    
} catch {
    Write-Host "  Error: $_" -ForegroundColor Red
}

Write-Host ""

# 8. Fraud Detection
Invoke-SqlQuery -Description "8. FRAUD DETECTION - Multiple Failed Attempts" -Query @"
SELECT 
    UserId,
    COUNT(*) AS FailedAttempts,
    MAX(AttemptedAt) AS LastAttempt,
    COUNT(DISTINCT IpAddress) AS DistinctIPs
FROM RedemptionHistory
WHERE Success = 0
GROUP BY UserId
HAVING COUNT(*) >= 2
ORDER BY FailedAttempts DESC;
"@

# 9. Performance Metrics
Invoke-SqlQuery -Description "9. CAMPAIGN PERFORMANCE METRICS" -Query @"
SELECT 
    c.CampaignId,
    c.Name,
    c.MaxTotalRedemptions,
    c.CurrentRedemptions,
    CASE 
        WHEN c.MaxTotalRedemptions IS NOT NULL 
        THEN CAST(c.CurrentRedemptions AS FLOAT) / c.MaxTotalRedemptions * 100
        ELSE NULL
    END AS RedemptionPercentage,
    (SELECT COUNT(*) FROM Coupons WHERE CampaignId = c.CampaignId) AS TotalCoupons,
    (SELECT COUNT(*) FROM Coupons WHERE CampaignId = c.CampaignId AND IsRedeemed = 1) AS RedeemedCoupons,
    DATEDIFF(DAY, c.StartDate, c.EndDate) AS CampaignDurationDays,
    DATEDIFF(DAY, GETUTCDATE(), c.EndDate) AS DaysRemaining
FROM Campaigns c
WHERE c.IsActive = 1
ORDER BY RedemptionPercentage DESC;
"@

# 10. Data Quality
Invoke-SqlQuery -Description "10. DATA QUALITY - Expired Unredeemed Coupons" -Query @"
SELECT COUNT(*) AS ExpiredUnredeemedCoupons
FROM Coupons
WHERE IsRedeemed = 0 AND ExpiresAt < GETUTCDATE();
"@

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "✓ VERIFICATION COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""
