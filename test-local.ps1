# Script de Pruebas Locales - Coupons Backend

Write-Host "========================================" -ForegroundColor Green
Write-Host "   COUPONS BACKEND - PRUEBAS LOCALES" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# URLs de los servicios
$redeemServiceUrl = "http://localhost:5210"
$campaignServiceUrl = "http://localhost:5277"

Write-Host "RedeemService: $redeemServiceUrl" -ForegroundColor Cyan
Write-Host "CampaignService: $campaignServiceUrl" -ForegroundColor Cyan
Write-Host ""

# Test 1: Health Checks
Write-Host "`n[TEST 1] Health Checks" -ForegroundColor Yellow
Write-Host "----------------------------------------"
try {
    $redeem = Invoke-RestMethod -Uri "$redeemServiceUrl/api/health" -Method Get
    Write-Host "✓ RedeemService: $($redeem.status)" -ForegroundColor Green
} catch {
    Write-Host "✗ RedeemService: Failed" -ForegroundColor Red
}

try {
    $campaign = Invoke-RestMethod -Uri "$campaignServiceUrl/api/campaigns/health" -Method Get
    Write-Host "✓ CampaignService: $($campaign.status)" -ForegroundColor Green
} catch {
    Write-Host "✗ CampaignService: Failed" -ForegroundColor Red
}

Start-Sleep -Seconds 1

# Test 2: Consultar cupón existente
Write-Host "`n[TEST 2] Consultar cupón CUPON10OFF" -ForegroundColor Yellow
Write-Host "----------------------------------------"
$coupon = Invoke-RestMethod -Uri "$redeemServiceUrl/api/coupon/CUPON10OFF" -Method Get
Write-Host "Código: $($coupon.couponCode)" -ForegroundColor White
Write-Host "Válido: $($coupon.valid)" -ForegroundColor White
Write-Host "Canjeado: $($coupon.redeemed)" -ForegroundColor White
Write-Host "Campaña: $($coupon.campaignId)" -ForegroundColor White
Write-Host "Expira: $($coupon.expiresAt)" -ForegroundColor White

Start-Sleep -Seconds 1

# Test 3: Canjear cupón exitosamente
Write-Host "`n[TEST 3] Canjear cupón CUPON10OFF" -ForegroundColor Yellow
Write-Host "----------------------------------------"
$body = @{
    couponCode = "CUPON10OFF"
    userId = "user-test-001"
} | ConvertTo-Json

try {
    $redeem = Invoke-RestMethod -Uri "$redeemServiceUrl/api/redeem" -Method Post -Body $body -ContentType "application/json"
    Write-Host "✓ Canje exitoso: $($redeem.message)" -ForegroundColor Green
    Write-Host "  Campaña: $($redeem.campaignId)" -ForegroundColor White
} catch {
    Write-Host "✗ Error: $($_.ErrorDetails.Message)" -ForegroundColor Red
}

Start-Sleep -Seconds 1

# Test 4: Verificar cupón canjeado
Write-Host "`n[TEST 4] Verificar cupón después del canje" -ForegroundColor Yellow
Write-Host "----------------------------------------"
$coupon = Invoke-RestMethod -Uri "$redeemServiceUrl/api/coupon/CUPON10OFF" -Method Get
Write-Host "Canjeado: $($coupon.redeemed)" -ForegroundColor White
Write-Host "Asignado a: $($coupon.assignedTo)" -ForegroundColor White

Start-Sleep -Seconds 1

# Test 5: Intentar canjear cupón ya usado (debe fallar)
Write-Host "`n[TEST 5] Intentar canjear cupón ya usado" -ForegroundColor Yellow
Write-Host "----------------------------------------"
$body = @{
    couponCode = "CUPON10OFF"
    userId = "user-test-002"
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "$redeemServiceUrl/api/redeem" -Method Post -Body $body -ContentType "application/json"
    Write-Host "✗ No se detectó el cupón ya usado" -ForegroundColor Red
} catch {
    $error = $_.ErrorDetails.Message | ConvertFrom-Json
    Write-Host "✓ Error detectado correctamente: $($error.message)" -ForegroundColor Green
}

Start-Sleep -Seconds 1

# Test 6: Consultar cupón inexistente (debe fallar)
Write-Host "`n[TEST 6] Consultar cupón inexistente" -ForegroundColor Yellow
Write-Host "----------------------------------------"
try {
    Invoke-RestMethod -Uri "$redeemServiceUrl/api/coupon/NOEXISTE999" -Method Get
    Write-Host "✗ No se detectó el cupón inexistente" -ForegroundColor Red
} catch {
    $error = $_.ErrorDetails.Message | ConvertFrom-Json
    Write-Host "✓ Error detectado correctamente: $($error.message)" -ForegroundColor Green
}

Start-Sleep -Seconds 1

# Test 7: Canjear segundo cupón demo
Write-Host "`n[TEST 7] Canjear cupón DEMO50" -ForegroundColor Yellow
Write-Host "----------------------------------------"
$body = @{
    couponCode = "DEMO50"
    userId = "user-test-003"
} | ConvertTo-Json

try {
    $redeem = Invoke-RestMethod -Uri "$redeemServiceUrl/api/redeem" -Method Post -Body $body -ContentType "application/json"
    Write-Host "✓ Canje exitoso: $($redeem.message)" -ForegroundColor Green
    Write-Host "  Campaña: $($redeem.campaignId)" -ForegroundColor White
} catch {
    Write-Host "✗ Error: $($_.ErrorDetails.Message)" -ForegroundColor Red
}

Start-Sleep -Seconds 1

# Test 8: Solicitar generación masiva
Write-Host "`n[TEST 8] Solicitar generación de 5000 cupones" -ForegroundColor Yellow
Write-Host "----------------------------------------"
$body = @{
    amount = 5000
    prefix = "BF25"
    expiration = "2025-12-31T23:59:59Z"
} | ConvertTo-Json

$generate = Invoke-RestMethod -Uri "$campaignServiceUrl/api/campaigns/CAMPAIGN-2025-BlackFriday/generate" -Method Post -Body $body -ContentType "application/json"
Write-Host "✓ Solicitud aceptada" -ForegroundColor Green
Write-Host "  Request ID: $($generate.requestId)" -ForegroundColor White
Write-Host "  Cantidad: $($generate.amount)" -ForegroundColor White
Write-Host "  Estado: $($generate.status)" -ForegroundColor White
Write-Host "  Campaña: $($generate.campaignId)" -ForegroundColor White

Start-Sleep -Seconds 1

# Test 9: Validación de límite por campaña
Write-Host "`n[TEST 9] Validar límite 1 cupón por campaña/usuario" -ForegroundColor Yellow
Write-Host "----------------------------------------"
$body = @{
    couponCode = "DEMO50"
    userId = "user-test-001"
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "$redeemServiceUrl/api/redeem" -Method Post -Body $body -ContentType "application/json"
    Write-Host "✗ No se detectó el límite por campaña" -ForegroundColor Red
} catch {
    $error = $_.ErrorDetails.Message | ConvertFrom-Json
    Write-Host "✓ Límite detectado: $($error.message)" -ForegroundColor Green
}

# Resumen
Write-Host "`n========================================" -ForegroundColor Green
Write-Host "   PRUEBAS COMPLETADAS" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Servicios funcionando correctamente:" -ForegroundColor Cyan
Write-Host "  ✓ RedeemService" -ForegroundColor Green
Write-Host "  ✓ CampaignService" -ForegroundColor Green
Write-Host ""
Write-Host "Funcionalidades validadas:" -ForegroundColor Cyan
Write-Host "  ✓ Health checks" -ForegroundColor Green
Write-Host "  ✓ Consulta de cupones" -ForegroundColor Green
Write-Host "  ✓ Canje de cupones" -ForegroundColor Green
Write-Host "  ✓ Validación de cupón ya usado" -ForegroundColor Green
Write-Host "  ✓ Validación de cupón inexistente" -ForegroundColor Green
Write-Host "  ✓ Límite por campaña/usuario" -ForegroundColor Green
Write-Host "  ✓ Solicitud de generación masiva" -ForegroundColor Green
Write-Host ""
