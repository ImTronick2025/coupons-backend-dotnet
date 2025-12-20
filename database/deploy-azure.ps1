# =============================================
# PowerShell Script: Deploy Database to Azure SQL
# Usage: .\deploy-azure.ps1 -ServerName "server.database.windows.net" -DatabaseName "coupons-db" -Username "sqladmin" -Password "password"
# =============================================

param(
    [Parameter(Mandatory=$true)]
    [string]$ServerName,
    
    [Parameter(Mandatory=$true)]
    [string]$DatabaseName,
    
    [Parameter(Mandatory=$true)]
    [string]$Username,
    
    [Parameter(Mandatory=$true)]
    [string]$Password,
    
    [Parameter(Mandatory=$false)]
    [switch]$SchemaOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$SampleDataOnly
)

$ErrorActionPreference = "Stop"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Azure SQL Database Deployment Script" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SchemaFile = Join-Path $ScriptDir "schema.sql"
$SampleDataFile = Join-Path $ScriptDir "sample-data.sql"

# Verify files exist
if (-not (Test-Path $SchemaFile)) {
    Write-Error "Schema file not found: $SchemaFile"
    exit 1
}

if (-not $SchemaOnly -and -not (Test-Path $SampleDataFile)) {
    Write-Error "Sample data file not found: $SampleDataFile"
    exit 1
}

# Build connection string
$ConnectionString = "Server=tcp:$ServerName,1433;Initial Catalog=$DatabaseName;Persist Security Info=False;User ID=$Username;Password=$Password;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

Write-Host "Connection Details:" -ForegroundColor Yellow
Write-Host "  Server: $ServerName" -ForegroundColor Gray
Write-Host "  Database: $DatabaseName" -ForegroundColor Gray
Write-Host "  Username: $Username" -ForegroundColor Gray
Write-Host ""

# Test connection
Write-Host "Testing connection..." -ForegroundColor Yellow
try {
    $TestConnection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $TestConnection.Open()
    Write-Host "  ✓ Connection successful!" -ForegroundColor Green
    $TestConnection.Close()
} catch {
    Write-Error "Failed to connect to database: $_"
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "  1. Check firewall rules (add your IP)" -ForegroundColor Gray
    Write-Host "  2. Verify username and password" -ForegroundColor Gray
    Write-Host "  3. Ensure database exists" -ForegroundColor Gray
    exit 1
}

Write-Host ""

# Function to execute SQL file
function Invoke-SqlFile {
    param(
        [string]$FilePath,
        [string]$ConnectionString,
        [string]$Description
    )
    
    Write-Host "Executing: $Description" -ForegroundColor Yellow
    Write-Host "  File: $FilePath" -ForegroundColor Gray
    
    try {
        # Read file content
        $SqlContent = Get-Content -Path $FilePath -Raw
        
        # Split by GO statements
        $SqlBatches = $SqlContent -split '\r?\nGO\r?\n'
        
        $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
        $Connection.Open()
        
        $BatchNumber = 0
        $TotalBatches = $SqlBatches.Count
        
        foreach ($Batch in $SqlBatches) {
            $BatchNumber++
            $TrimmedBatch = $Batch.Trim()
            
            if ([string]::IsNullOrWhiteSpace($TrimmedBatch)) {
                continue
            }
            
            Write-Progress -Activity "Executing SQL" -Status "Batch $BatchNumber of $TotalBatches" -PercentComplete (($BatchNumber / $TotalBatches) * 100)
            
            $Command = $Connection.CreateCommand()
            $Command.CommandText = $TrimmedBatch
            $Command.CommandTimeout = 300 # 5 minutes
            
            try {
                $Command.ExecuteNonQuery() | Out-Null
            } catch {
                Write-Error "Error in batch $BatchNumber : $_"
                throw
            }
        }
        
        Write-Progress -Activity "Executing SQL" -Completed
        $Connection.Close()
        
        Write-Host "  ✓ Completed successfully!" -ForegroundColor Green
        Write-Host ""
        
    } catch {
        Write-Error "Failed to execute $Description : $_"
        throw
    }
}

# Deploy schema
if (-not $SampleDataOnly) {
    Invoke-SqlFile -FilePath $SchemaFile -ConnectionString $ConnectionString -Description "Database Schema"
}

# Deploy sample data
if (-not $SchemaOnly) {
    Invoke-SqlFile -FilePath $SampleDataFile -ConnectionString $ConnectionString -Description "Sample Data"
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Deployment Completed Successfully!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Verification
Write-Host "Verifying deployment..." -ForegroundColor Yellow
try {
    $Connection = New-Object System.Data.SqlClient.SqlConnection($ConnectionString)
    $Connection.Open()
    
    # Count campaigns
    $Command = $Connection.CreateCommand()
    $Command.CommandText = "SELECT COUNT(*) FROM Campaigns"
    $CampaignCount = $Command.ExecuteScalar()
    Write-Host "  Campaigns: $CampaignCount" -ForegroundColor Gray
    
    # Count coupons
    $Command.CommandText = "SELECT COUNT(*) FROM Coupons"
    $CouponCount = $Command.ExecuteScalar()
    Write-Host "  Coupons: $CouponCount" -ForegroundColor Gray
    
    # Count redemptions
    $Command.CommandText = "SELECT COUNT(*) FROM RedemptionHistory"
    $RedemptionCount = $Command.ExecuteScalar()
    Write-Host "  Redemption Attempts: $RedemptionCount" -ForegroundColor Gray
    
    $Connection.Close()
    
    Write-Host ""
    Write-Host "  ✓ Verification successful!" -ForegroundColor Green
    
} catch {
    Write-Warning "Verification failed: $_"
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Test stored procedures" -ForegroundColor Gray
Write-Host "  2. Configure connection strings in microservices" -ForegroundColor Gray
Write-Host "  3. Test API endpoints" -ForegroundColor Gray
Write-Host ""
