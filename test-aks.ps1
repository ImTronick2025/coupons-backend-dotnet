# Script de Pruebas para Servicios en AKS
# Coupons Backend

param(
    [Parameter(Mandatory=$true)]
    [string]$IngressIp
)

$ErrorActionPreference = "Continue"

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                            ║" -ForegroundColor Cyan
Write-Host "║         PRUEBAS DE SERVICIOS EN AKS - COUPONS BACKEND     ║" -ForegroundColor Cyan
Write-Host "║                                                            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$baseUrl = "http://$IngressIp"
Write-Host "Base URL: $baseUrl" -ForegroundColor Yellow
Write-Host ""

$testsPassed = 0
$testsFailed = 0

function Test-Endpoint {
    param(
        [string]$Name,
        [string]$Method,
        [string]$Url,
        [object]$Body = $null,
        [int]$ExpectedStatus = 200
    )
    
    Write-Host "[$Name]" -ForegroundColor Yellow
    Write-Host "  $Method $Url" -ForegroundColor Gray
    
    try {
        if ($Method -eq "GET") {
            $response = Invoke-RestMethod -Uri $Url -Method Get -ErrorAction Stop
        } else {
            $bodyJson = $Body | ConvertTo-Json
            $response = Invoke-RestMethod -Uri $Url -Method Post -Body $bodyJson -ContentType "application/json" -ErrorAction Stop
        }
        
        Write-Host "  ✓ Success ($ExpectedStatus)" -ForegroundColor Green
        $response | ConvertTo-Json -Depth 3 | Write-Host -ForegroundColor Gray
        $script:testsPassed++
        return $true
    } catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        if ($statusCode -eq $ExpectedStatus) {
            Write-Host "  ✓ Expected error ($ExpectedStatus)" -ForegroundColor Green
            $_.ErrorDetails.Message | ConvertFrom-Json | ConvertTo-Json | Write-Host -ForegroundColor Gray
            $script:testsPassed++
            return $true
        } else {
            Write-Host "  ✗ Failed (Status: $statusCode)" -ForegroundColor Red
            Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
            $script:testsFailed++
            return $false
        }
    }
    Write-Host ""
}

# ============================================================
# TEST 1: HEALTH CHECKS
# ============================================================

Write-Host "`n[TEST SUITE 1] Health Checks" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Test-Endpoint -Name "Health Check - RedeemService" `
    -Method "GET" `
    -Url "$baseUrl/api/health"

Start-Sleep -Seconds 1

Test-Endpoint -Name "Health Check - CampaignService" `
    -Method "GET" `
    -Url "$baseUrl/api/campaigns/health"

# ============================================================
# TEST 2: COUPON QUERIES
# ============================================================

Write-Host "`n[TEST SUITE 2] Consultas de Cupones" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Test-Endpoint -Name "Consultar cupón CUPON10OFF" `
    -Method "GET" `
    -Url "$baseUrl/api/coupon/CUPON10OFF"

Start-Sleep -Seconds 1

Test-Endpoint -Name "Consultar cupón DEMO50" `
    -Method "GET" `
    -Url "$baseUrl/api/coupon/DEMO50"

Start-Sleep -Seconds 1

Test-Endpoint -Name "Consultar cupón inexistente (404)" `
    -Method "GET" `
    -Url "$baseUrl/api/coupon/NOEXISTE999" `
    -ExpectedStatus 404

# ============================================================
# TEST 3: COUPON REDEMPTION
# ============================================================

Write-Host "`n[TEST SUITE 3] Canje de Cupones" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$redeemBody1 = @{
    couponCode = "CUPON10OFF"
    userId = "aks-test-user-001"
}

Test-Endpoint -Name "Canjear cupón CUPON10OFF" `
    -Method "POST" `
    -Url "$baseUrl/api/redeem" `
    -Body $redeemBody1

Start-Sleep -Seconds 1

$redeemBody2 = @{
    couponCode = "CUPON10OFF"
    userId = "aks-test-user-002"
}

Test-Endpoint -Name "Intentar canjear cupón ya usado (400)" `
    -Method "POST" `
    -Url "$baseUrl/api/redeem" `
    -Body $redeemBody2 `
    -ExpectedStatus 400

Start-Sleep -Seconds 1

$redeemBody3 = @{
    couponCode = "DEMO50"
    userId = "aks-test-user-003"
}

Test-Endpoint -Name "Canjear cupón DEMO50" `
    -Method "POST" `
    -Url "$baseUrl/api/redeem" `
    -Body $redeemBody3

# ============================================================
# TEST 4: COUPON GENERATION
# ============================================================

Write-Host "`n[TEST SUITE 4] Generación Masiva" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

$generateBody = @{
    amount = 1000
    prefix = "AKS"
    expiration = "2025-12-31T23:59:59Z"
}

Test-Endpoint -Name "Solicitar generación de 1000 cupones (202)" `
    -Method "POST" `
    -Url "$baseUrl/api/campaigns/CAMPAIGN-2025-AKS-Test/generate" `
    -Body $generateBody `
    -ExpectedStatus 202

# ============================================================
# TEST 5: LOAD TEST (OPCIONAL)
# ============================================================

Write-Host "`n[TEST SUITE 5] Prueba de Carga Básica" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "Ejecutando 10 peticiones concurrentes..." -ForegroundColor Yellow

$jobs = 1..10 | ForEach-Object {
    Start-Job -ScriptBlock {
        param($url)
        try {
            Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
            return "OK"
        } catch {
            return "FAILED"
        }
    } -ArgumentList "$baseUrl/api/health"
}

$results = $jobs | Wait-Job | Receive-Job
$jobs | Remove-Job

$successful = ($results | Where-Object { $_ -eq "OK" }).Count
$failed = ($results | Where-Object { $_ -ne "OK" }).Count

Write-Host "  Exitosas: $successful/10" -ForegroundColor Green
Write-Host "  Fallidas:  $failed/10" -ForegroundColor $(if($failed -eq 0){"Green"}else{"Red"})

if ($successful -eq 10) {
    $script:testsPassed++
} else {
    $script:testsFailed++
}

# ============================================================
# TEST 6: POD STATUS
# ============================================================

Write-Host "`n[TEST SUITE 6] Estado de Pods" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "Verificando pods..." -ForegroundColor Yellow
kubectl get pods -l app=redeem-service
kubectl get pods -l app=campaign-service
Write-Host ""

Write-Host "Verificando servicios..." -ForegroundColor Yellow
kubectl get services redeem-service campaign-service
Write-Host ""

Write-Host "Verificando HPA..." -ForegroundColor Yellow
kubectl get hpa
Write-Host ""

# ============================================================
# RESUMEN
# ============================================================

Write-Host "`n╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                            ║" -ForegroundColor Green
Write-Host "║                    RESUMEN DE PRUEBAS                      ║" -ForegroundColor Green
Write-Host "║                                                            ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

$total = $testsPassed + $testsFailed
$percentage = if ($total -gt 0) { [math]::Round(($testsPassed / $total) * 100, 2) } else { 0 }

Write-Host "Total de pruebas: $total" -ForegroundColor White
Write-Host "  ✓ Exitosas: $testsPassed" -ForegroundColor Green
Write-Host "  ✗ Fallidas: $testsFailed" -ForegroundColor $(if($testsFailed -eq 0){"Green"}else{"Red"})
Write-Host "  Porcentaje: $percentage%" -ForegroundColor $(if($percentage -eq 100){"Green"}else{"Yellow"})
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "🎉 ¡TODAS LAS PRUEBAS PASARON!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Algunas pruebas fallaron. Revisar logs:" -ForegroundColor Yellow
    Write-Host "  kubectl logs -l app=redeem-service --tail=50" -ForegroundColor Gray
    Write-Host "  kubectl logs -l app=campaign-service --tail=50" -ForegroundColor Gray
}

Write-Host ""
Write-Host "📊 COMANDOS ÚTILES:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Ver logs en tiempo real:" -ForegroundColor White
Write-Host "  kubectl logs -l app=redeem-service -f" -ForegroundColor Gray
Write-Host ""
Write-Host "  Escalar manualmente:" -ForegroundColor White
Write-Host "  kubectl scale deployment redeem-service --replicas=5" -ForegroundColor Gray
Write-Host ""
Write-Host "  Reiniciar deployments:" -ForegroundColor White
Write-Host "  kubectl rollout restart deployment/redeem-service" -ForegroundColor Gray
Write-Host ""
Write-Host "  Verificar eventos:" -ForegroundColor White
Write-Host "  kubectl get events --sort-by='.lastTimestamp'" -ForegroundColor Gray
Write-Host ""

exit $(if($testsFailed -eq 0){0}else{1})
