# Guía Rápida: Despliegue a AKS

## 🚀 Despliegue en 3 Comandos

### Paso 1: Configurar variables

```powershell
$AcrName = "tuacr"              # Tu ACR name (sin .azurecr.io)
$AksName = "tuaks"              # Tu AKS name
$ResourceGroup = "tu-rg"        # Tu resource group
```

### Paso 2: Ejecutar deploy

```powershell
.\deploy-to-aks.ps1 -AcrName $AcrName -AksName $AksName -ResourceGroup $ResourceGroup
```

### Paso 3: Probar servicios

```powershell
# Obtener IP del Ingress
$IngressIp = (kubectl get ingress coupons-ingress -o json | ConvertFrom-Json).status.loadBalancer.ingress[0].ip

# Ejecutar pruebas
.\test-aks.ps1 -IngressIp $IngressIp
```

---

## 📋 Pre-requisitos

### 1. Infraestructura Azure

Debes tener creados:

```bash
# Crear Resource Group
az group create --name rg-coupons --location eastus

# Crear ACR
az acr create --name couponsacr --resource-group rg-coupons --sku Basic

# Crear AKS
az aks create \
  --name coupons-aks \
  --resource-group rg-coupons \
  --node-count 2 \
  --node-vm-size Standard_B2s \
  --enable-managed-identity \
  --attach-acr couponsacr \
  --generate-ssh-keys
```

### 2. Herramientas Locales

- ✅ Azure CLI: https://aka.ms/installazurecliwindows
- ✅ kubectl (se instala automáticamente con el script)
- ✅ Docker Desktop (para build local, opcional)

---

## 🎯 Proceso Completo Automatizado

El script `deploy-to-aks.ps1` realiza:

### Fase 1: Verificación
- ✓ Azure CLI instalado
- ✓ kubectl instalado
- ✓ Login a Azure
- ✓ ACR existe
- ✓ AKS existe

### Fase 2: Build & Push
- ✓ Login a ACR
- ✓ Build RedeemService image
- ✓ Push RedeemService to ACR
- ✓ Build CampaignService image
- ✓ Push CampaignService to ACR

### Fase 3: Configuración AKS
- ✓ Obtener credenciales AKS
- ✓ Vincular ACR a AKS
- ✓ Instalar NGINX Ingress (si no existe)

### Fase 4: Deploy
- ✓ Deploy RedeemService (Deployment + Service + HPA)
- ✓ Deploy CampaignService (Deployment + Service + HPA)
- ✓ Deploy Ingress
- ✓ Esperar pods ready

### Fase 5: Verificación
- ✓ Listar pods
- ✓ Listar services
- ✓ Listar HPAs
- ✓ Obtener IP pública Ingress

---

## 🧪 Script de Pruebas

El script `test-aks.ps1` ejecuta:

### Suite 1: Health Checks
- RedeemService health
- CampaignService health

### Suite 2: Consultas
- Cupón válido
- Cupón inexistente (404)

### Suite 3: Canje
- Canje exitoso
- Canje duplicado (400)

### Suite 4: Generación
- Solicitud masiva (202)

### Suite 5: Load Test
- 10 peticiones concurrentes

### Suite 6: Pod Status
- Estado de pods
- Estado de services
- Estado de HPAs

---

## 🔧 Opciones del Script

### Solo Build (sin deploy)

```powershell
.\deploy-to-aks.ps1 `
  -AcrName $AcrName `
  -AksName $AksName `
  -ResourceGroup $ResourceGroup `
  -SkipDeploy
```

### Solo Deploy (sin build)

```powershell
.\deploy-to-aks.ps1 `
  -AcrName $AcrName `
  -AksName $AksName `
  -ResourceGroup $ResourceGroup `
  -SkipBuild
```

### Deploy completo

```powershell
.\deploy-to-aks.ps1 `
  -AcrName $AcrName `
  -AksName $AksName `
  -ResourceGroup $ResourceGroup
```

---

## 📊 Verificación Manual

### Ver estado de pods

```bash
kubectl get pods
kubectl describe pod <pod-name>
```

### Ver logs

```bash
# Logs de RedeemService
kubectl logs -l app=redeem-service --tail=50 -f

# Logs de CampaignService
kubectl logs -l app=campaign-service --tail=50 -f
```

### Ver servicios

```bash
kubectl get services
kubectl get ingress
```

### Ver métricas HPA

```bash
kubectl get hpa
kubectl describe hpa redeem-service-hpa
```

---

## 🌐 Probar Endpoints

Una vez obtenida la IP del Ingress:

```powershell
$IngressIp = "<TU_IP_INGRESS>"

# Health checks
Invoke-RestMethod -Uri "http://$IngressIp/api/health" -Method Get
Invoke-RestMethod -Uri "http://$IngressIp/api/campaigns/health" -Method Get

# Consultar cupón
Invoke-RestMethod -Uri "http://$IngressIp/api/coupon/CUPON10OFF" -Method Get

# Canjear cupón
$body = @{
    couponCode = "CUPON10OFF"
    userId = "user-aks-001"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://$IngressIp/api/redeem" `
    -Method Post `
    -Body $body `
    -ContentType "application/json"

# Generar cupones
$body = @{
    amount = 1000
    prefix = "AKS"
    expiration = "2025-12-31T23:59:59Z"
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://$IngressIp/api/campaigns/CAMPAIGN-AKS/generate" `
    -Method Post `
    -Body $body `
    -ContentType "application/json"
```

---

## 🔄 Actualizar Servicios

### Rebuild y redeploy

```powershell
# Build nueva versión
docker build -f src/RedeemService/Dockerfile -t $AcrName.azurecr.io/redeem-service:v2 .
docker push $AcrName.azurecr.io/redeem-service:v2

# Actualizar deployment
kubectl set image deployment/redeem-service redeem-service=$AcrName.azurecr.io/redeem-service:v2

# Verificar rollout
kubectl rollout status deployment/redeem-service
```

### Rollback

```bash
kubectl rollout undo deployment/redeem-service
kubectl rollout status deployment/redeem-service
```

---

## 🗑️ Limpieza

### Eliminar servicios de AKS

```bash
kubectl delete -f k8s/ingress-simple.yaml
kubectl delete -f k8s/campaign-service-simple.yaml
kubectl delete -f k8s/redeem-service-simple.yaml
```

### Eliminar todo (incluye infraestructura)

```bash
# Eliminar resource group completo
az group delete --name rg-coupons --yes --no-wait
```

---

## ⚠️ Troubleshooting

### Pods en estado Pending

```bash
kubectl describe pod <pod-name>
# Verificar si hay problemas de recursos o pulling images
```

### Pods en CrashLoopBackOff

```bash
kubectl logs <pod-name>
# Ver logs para identificar error
```

### Ingress sin IP

```bash
# Verificar NGINX Ingress Controller
kubectl get pods -n ingress-nginx

# Reinstalar si es necesario
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
```

### Pods no pueden pull images de ACR

```bash
# Re-vincular ACR
az aks update --name $AksName --resource-group $ResourceGroup --attach-acr $AcrName

# Verificar conexión
az aks check-acr --name $AksName --resource-group $ResourceGroup --acr $AcrName.azurecr.io
```

---

## 📚 Recursos Adicionales

- [AKS Documentation](https://docs.microsoft.com/azure/aks/)
- [ACR Documentation](https://docs.microsoft.com/azure/container-registry/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [NGINX Ingress](https://kubernetes.github.io/ingress-nginx/)

---

## ✅ Checklist Final

Antes de considerarlo completo:

- [ ] Pods en estado Running
- [ ] Services con ClusterIP asignado
- [ ] Ingress con IP pública
- [ ] Health checks responden 200
- [ ] Endpoints funcionan correctamente
- [ ] HPA configurado y activo
- [ ] Logs sin errores críticos
