# Script de Despliegue Completo a AKS
# Coupons Backend - Microservicios

param(
    [Parameter(Mandatory=$true)]
    [string]$AcrName,
    
    [Parameter(Mandatory=$true)]
    [string]$AksName,
    
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDeploy
)

$ErrorActionPreference = "Stop"

Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                            ║" -ForegroundColor Cyan
Write-Host "║     DESPLIEGUE A AKS - COUPONS BACKEND MICROSERVICES      ║" -ForegroundColor Cyan
Write-Host "║                                                            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "Configuración:" -ForegroundColor Yellow
Write-Host "  ACR Name:       $AcrName" -ForegroundColor White
Write-Host "  AKS Name:       $AksName" -ForegroundColor White
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
Write-Host ""

# ============================================================
# FASE 1: VERIFICACIÓN DE PREREQUISITOS
# ============================================================

Write-Host "[FASE 1] Verificando prerequisitos..." -ForegroundColor Cyan
Write-Host ""

# Verificar Azure CLI
Write-Host "  Verificando Azure CLI..." -ForegroundColor Yellow
try {
    az --version | Out-Null
    Write-Host "  ✓ Azure CLI instalado" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Azure CLI no encontrado. Instalar desde: https://aka.ms/installazurecliwindows" -ForegroundColor Red
    exit 1
}

# Verificar kubectl
Write-Host "  Verificando kubectl..." -ForegroundColor Yellow
try {
    kubectl version --client | Out-Null
    Write-Host "  ✓ kubectl instalado" -ForegroundColor Green
} catch {
    Write-Host "  ✗ kubectl no encontrado. Instalando..." -ForegroundColor Yellow
    az aks install-cli
}

# Verificar login Azure
Write-Host "  Verificando autenticación Azure..." -ForegroundColor Yellow
$account = az account show 2>$null | ConvertFrom-Json
if ($null -eq $account) {
    Write-Host "  ✗ No autenticado en Azure. Ejecutando login..." -ForegroundColor Yellow
    az login
}
Write-Host "  ✓ Autenticado como: $($account.user.name)" -ForegroundColor Green

# Verificar ACR
Write-Host "  Verificando ACR '$AcrName'..." -ForegroundColor Yellow
$acr = az acr show --name $AcrName --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
if ($null -eq $acr) {
    Write-Host "  ✗ ACR '$AcrName' no encontrado en '$ResourceGroup'" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ ACR encontrado: $($acr.loginServer)" -ForegroundColor Green

# Verificar AKS
Write-Host "  Verificando AKS '$AksName'..." -ForegroundColor Yellow
$aks = az aks show --name $AksName --resource-group $ResourceGroup 2>$null | ConvertFrom-Json
if ($null -eq $aks) {
    Write-Host "  ✗ AKS '$AksName' no encontrado en '$ResourceGroup'" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ AKS encontrado: $($aks.fqdn)" -ForegroundColor Green

Write-Host ""

# ============================================================
# FASE 2: CONSTRUCCIÓN Y PUSH DE IMÁGENES
# ============================================================

if (-not $SkipBuild) {
    Write-Host "[FASE 2] Construyendo y publicando imágenes Docker..." -ForegroundColor Cyan
    Write-Host ""

    # Login a ACR
    Write-Host "  Iniciando sesión en ACR..." -ForegroundColor Yellow
    az acr login --name $AcrName
    Write-Host "  ✓ Login exitoso" -ForegroundColor Green

    $acrLoginServer = "$AcrName.azurecr.io"

    # Build y push RedeemService
    Write-Host ""
    Write-Host "  [1/2] Construyendo RedeemService..." -ForegroundColor Yellow
    docker build -f src/RedeemService/Dockerfile -t "${acrLoginServer}/redeem-service:latest" -t "${acrLoginServer}/redeem-service:$(Get-Date -Format 'yyyyMMdd-HHmmss')" .
    
    Write-Host "  Publicando RedeemService a ACR..." -ForegroundColor Yellow
    docker push "${acrLoginServer}/redeem-service:latest"
    Write-Host "  ✓ RedeemService publicado" -ForegroundColor Green

    # Build y push CampaignService
    Write-Host ""
    Write-Host "  [2/2] Construyendo CampaignService..." -ForegroundColor Yellow
    docker build -f src/CampaignService/Dockerfile -t "${acrLoginServer}/campaign-service:latest" -t "${acrLoginServer}/campaign-service:$(Get-Date -Format 'yyyyMMdd-HHmmss')" .
    
    Write-Host "  Publicando CampaignService a ACR..." -ForegroundColor Yellow
    docker push "${acrLoginServer}/campaign-service:latest"
    Write-Host "  ✓ CampaignService publicado" -ForegroundColor Green

    Write-Host ""
    Write-Host "  Verificando imágenes en ACR..." -ForegroundColor Yellow
    az acr repository list --name $AcrName --output table
    Write-Host ""
} else {
    Write-Host "[FASE 2] OMITIDA (--SkipBuild)" -ForegroundColor Gray
    Write-Host ""
}

# ============================================================
# FASE 3: CONFIGURACIÓN DE AKS
# ============================================================

Write-Host "[FASE 3] Configurando AKS..." -ForegroundColor Cyan
Write-Host ""

# Obtener credenciales de AKS
Write-Host "  Obteniendo credenciales de AKS..." -ForegroundColor Yellow
az aks get-credentials --resource-group $ResourceGroup --name $AksName --overwrite-existing
Write-Host "  ✓ Credenciales configuradas" -ForegroundColor Green

# Verificar conexión
Write-Host "  Verificando conexión a AKS..." -ForegroundColor Yellow
kubectl get nodes
Write-Host "  ✓ Conectado a AKS" -ForegroundColor Green

# Vincular ACR a AKS (si no está vinculado)
Write-Host ""
Write-Host "  Verificando vinculación ACR-AKS..." -ForegroundColor Yellow
az aks update --name $AksName --resource-group $ResourceGroup --attach-acr $AcrName
Write-Host "  ✓ ACR vinculado a AKS" -ForegroundColor Green

# Verificar NGINX Ingress Controller
Write-Host ""
Write-Host "  Verificando NGINX Ingress Controller..." -ForegroundColor Yellow
$nginxPods = kubectl get pods -n ingress-nginx 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ⚠ NGINX Ingress no encontrado. Instalando..." -ForegroundColor Yellow
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
    Write-Host "  Esperando a que NGINX esté listo..." -ForegroundColor Yellow
    kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
    Write-Host "  ✓ NGINX Ingress instalado" -ForegroundColor Green
} else {
    Write-Host "  ✓ NGINX Ingress ya instalado" -ForegroundColor Green
}

Write-Host ""

# ============================================================
# FASE 4: DESPLIEGUE DE MICROSERVICIOS
# ============================================================

if (-not $SkipDeploy) {
    Write-Host "[FASE 4] Desplegando microservicios a AKS..." -ForegroundColor Cyan
    Write-Host ""

    # Actualizar manifiestos con ACR name
    Write-Host "  Preparando manifiestos K8s..." -ForegroundColor Yellow
    
    $redeemManifest = Get-Content "k8s/redeem-service-simple.yaml" -Raw
    $redeemManifest = $redeemManifest -replace '<ACR_NAME>', $AcrName
    $redeemManifest | Set-Content "k8s/redeem-service-simple.temp.yaml"

    $campaignManifest = Get-Content "k8s/campaign-service-simple.yaml" -Raw
    $campaignManifest = $campaignManifest -replace '<ACR_NAME>', $AcrName
    $campaignManifest | Set-Content "k8s/campaign-service-simple.temp.yaml"

    Write-Host "  ✓ Manifiestos preparados" -ForegroundColor Green

    # Desplegar RedeemService
    Write-Host ""
    Write-Host "  [1/3] Desplegando RedeemService..." -ForegroundColor Yellow
    kubectl apply -f k8s/redeem-service-simple.temp.yaml
    Write-Host "  ✓ RedeemService desplegado" -ForegroundColor Green

    # Desplegar CampaignService
    Write-Host ""
    Write-Host "  [2/3] Desplegando CampaignService..." -ForegroundColor Yellow
    kubectl apply -f k8s/campaign-service-simple.temp.yaml
    Write-Host "  ✓ CampaignService desplegado" -ForegroundColor Green

    # Desplegar Ingress
    Write-Host ""
    Write-Host "  [3/3] Desplegando Ingress..." -ForegroundColor Yellow
    kubectl apply -f k8s/ingress-simple.yaml
    Write-Host "  ✓ Ingress desplegado" -ForegroundColor Green

    # Limpiar archivos temporales
    Remove-Item "k8s/redeem-service-simple.temp.yaml" -ErrorAction SilentlyContinue
    Remove-Item "k8s/campaign-service-simple.temp.yaml" -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host "  Esperando a que los pods estén listos..." -ForegroundColor Yellow
    kubectl wait --for=condition=ready pod -l app=redeem-service --timeout=120s
    kubectl wait --for=condition=ready pod -l app=campaign-service --timeout=120s
    Write-Host "  ✓ Pods listos" -ForegroundColor Green

    Write-Host ""
} else {
    Write-Host "[FASE 4] OMITIDA (--SkipDeploy)" -ForegroundColor Gray
    Write-Host ""
}

# ============================================================
# FASE 5: VERIFICACIÓN Y ESTADO
# ============================================================

Write-Host "[FASE 5] Verificando despliegue..." -ForegroundColor Cyan
Write-Host ""

Write-Host "  Pods:" -ForegroundColor Yellow
kubectl get pods
Write-Host ""

Write-Host "  Servicios:" -ForegroundColor Yellow
kubectl get services
Write-Host ""

Write-Host "  HPAs:" -ForegroundColor Yellow
kubectl get hpa
Write-Host ""

Write-Host "  Ingress:" -ForegroundColor Yellow
kubectl get ingress
Write-Host ""

# Obtener IP del Ingress
Write-Host "  Obteniendo IP pública del Ingress..." -ForegroundColor Yellow
$ingressIp = ""
for ($i = 0; $i -lt 30; $i++) {
    $ingress = kubectl get ingress coupons-ingress -o json | ConvertFrom-Json
    if ($ingress.status.loadBalancer.ingress) {
        $ingressIp = $ingress.status.loadBalancer.ingress[0].ip
        break
    }
    Write-Host "  Esperando IP pública... ($i/30)" -ForegroundColor Gray
    Start-Sleep -Seconds 10
}

if ($ingressIp) {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                                                            ║" -ForegroundColor Green
    Write-Host "║              ✅ DESPLIEGUE COMPLETADO EXITOSAMENTE         ║" -ForegroundColor Green
    Write-Host "║                                                            ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "🌐 IP PÚBLICA DEL INGRESS: $ingressIp" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📋 ENDPOINTS DISPONIBLES:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Health Check (Redeem):" -ForegroundColor White
    Write-Host "  http://$ingressIp/api/health" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Health Check (Campaign):" -ForegroundColor White
    Write-Host "  http://$ingressIp/api/campaigns/health" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Consultar Cupón:" -ForegroundColor White
    Write-Host "  http://$ingressIp/api/coupon/CUPON10OFF" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Canjear Cupón (POST):" -ForegroundColor White
    Write-Host "  http://$ingressIp/api/redeem" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Generar Cupones (POST):" -ForegroundColor White
    Write-Host "  http://$ingressIp/api/campaigns/{id}/generate" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🧪 PROBAR ENDPOINTS:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Invoke-RestMethod -Uri `"http://$ingressIp/api/health`" -Method Get" -ForegroundColor Cyan
    Write-Host "  Invoke-RestMethod -Uri `"http://$ingressIp/api/coupon/CUPON10OFF`" -Method Get" -ForegroundColor Cyan
    Write-Host ""
} else {
    Write-Host "  ⚠ No se pudo obtener IP del Ingress después de 5 minutos" -ForegroundColor Yellow
    Write-Host "  Verificar con: kubectl get ingress coupons-ingress" -ForegroundColor Gray
}

Write-Host "📊 MONITOREO:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Ver logs de RedeemService:" -ForegroundColor White
Write-Host "  kubectl logs -l app=redeem-service --tail=50 -f" -ForegroundColor Gray
Write-Host ""
Write-Host "  Ver logs de CampaignService:" -ForegroundColor White
Write-Host "  kubectl logs -l app=campaign-service --tail=50 -f" -ForegroundColor Gray
Write-Host ""
Write-Host "  Ver métricas HPA:" -ForegroundColor White
Write-Host "  kubectl get hpa --watch" -ForegroundColor Gray
Write-Host ""
