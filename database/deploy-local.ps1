# =============================================
# PowerShell Script: Deploy Database Locally
# Usage: .\deploy-local.ps1 -ServerInstance "localhost" -DatabaseName "CouponsDb" -CreateDatabase
# =============================================

param(
    [Parameter(Mandatory=$false)]
    [string]$ServerInstance = "localhost",
    
    [Parameter(Mandatory=$false)]
    [string]$DatabaseName = "CouponsDb",
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateDatabase,
    
    [Parameter(Mandatory=$false)]
    [switch]$SchemaOnly,
    
    [Parameter(Mandatory=$false)]
    [switch]$UseTrustedConnection = $true
)

$ErrorActionPreference = "Stop"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Local SQL Server Database Deployment" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Check if SqlServer module is installed
if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Write-Host "SqlServer PowerShell module not found. Installing..." -ForegroundColor Yellow
    Install-Module -Name SqlServer -Scope CurrentUser -Force -AllowClobber
    Write-Host "  ✓ Module installed!" -ForegroundColor Green
}

Import-Module SqlServer

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

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Server: $ServerInstance" -ForegroundColor Gray
Write-Host "  Database: $DatabaseName" -ForegroundColor Gray
Write-Host "  Create Database: $CreateDatabase" -ForegroundColor Gray
Write-Host ""

# Test connection
Write-Host "Testing connection to SQL Server..." -ForegroundColor Yellow
try {
    $TestQuery = "SELECT @@VERSION AS Version"
    $Result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $TestQuery -TrustServerCertificate
    Write-Host "  ✓ Connected successfully!" -ForegroundColor Green
    Write-Host "  Version: $($Result.Version.Split([Environment]::NewLine)[0])" -ForegroundColor Gray
} catch {
    Write-Error "Failed to connect to SQL Server: $_"
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "  1. Ensure SQL Server is running" -ForegroundColor Gray
    Write-Host "  2. Check server instance name" -ForegroundColor Gray
    Write-Host "  3. Verify Windows Authentication is enabled" -ForegroundColor Gray
    exit 1
}

Write-Host ""

# Create database if requested
if ($CreateDatabase) {
    Write-Host "Creating database '$DatabaseName'..." -ForegroundColor Yellow
    try {
        $CreateDbQuery = @"
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'$DatabaseName')
BEGIN
    CREATE DATABASE [$DatabaseName]
    PRINT 'Database created successfully'
END
ELSE
BEGIN
    PRINT 'Database already exists'
END
"@
        Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $CreateDbQuery -TrustServerCertificate
        Write-Host "  ✓ Database ready!" -ForegroundColor Green
    } catch {
        Write-Error "Failed to create database: $_"
        exit 1
    }
    Write-Host ""
}

# Deploy schema
Write-Host "Deploying schema..." -ForegroundColor Yellow
try {
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -InputFile $SchemaFile -TrustServerCertificate -Verbose
    Write-Host "  ✓ Schema deployed successfully!" -ForegroundColor Green
} catch {
    Write-Error "Failed to deploy schema: $_"
    exit 1
}

Write-Host ""

# Deploy sample data
if (-not $SchemaOnly) {
    Write-Host "Deploying sample data..." -ForegroundColor Yellow
    try {
        Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -InputFile $SampleDataFile -TrustServerCertificate -Verbose
        Write-Host "  ✓ Sample data loaded successfully!" -ForegroundColor Green
    } catch {
        Write-Error "Failed to load sample data: $_"
        exit 1
    }
    Write-Host ""
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "Deployment Completed Successfully!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Verification
Write-Host "Verifying deployment..." -ForegroundColor Yellow
try {
    $VerifyQuery = @"
SELECT 
    (SELECT COUNT(*) FROM Campaigns) AS Campaigns,
    (SELECT COUNT(*) FROM Coupons) AS Coupons,
    (SELECT COUNT(*) FROM RedemptionHistory) AS RedemptionAttempts,
    (SELECT COUNT(*) FROM GenerationRequests) AS GenerationRequests
"@
    $Stats = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $DatabaseName -Query $VerifyQuery -TrustServerCertificate
    
    Write-Host "  Campaigns: $($Stats.Campaigns)" -ForegroundColor Gray
    Write-Host "  Coupons: $($Stats.Coupons)" -ForegroundColor Gray
    Write-Host "  Redemption Attempts: $($Stats.RedemptionAttempts)" -ForegroundColor Gray
    Write-Host "  Generation Requests: $($Stats.GenerationRequests)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ✓ Verification successful!" -ForegroundColor Green
    
} catch {
    Write-Warning "Verification failed: $_"
}

Write-Host ""
Write-Host "Connection String (for appsettings.json):" -ForegroundColor Yellow
Write-Host "  Server=$ServerInstance;Database=$DatabaseName;Trusted_Connection=True;TrustServerCertificate=True;" -ForegroundColor Cyan
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "  1. Test queries in SSMS or Azure Data Studio" -ForegroundColor Gray
Write-Host "  2. Configure connection string in .NET microservices" -ForegroundColor Gray
Write-Host "  3. Run API tests" -ForegroundColor Gray
Write-Host ""
