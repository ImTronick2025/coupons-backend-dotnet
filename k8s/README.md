# Kubernetes Deployment Guide

## Requisitos Previos

1. Cluster AKS configurado
2. Azure Container Registry (ACR) creado
3. kubectl configurado
4. Conexión del ACR con AKS establecida

## Pasos de Despliegue

### 1. Construir y publicar imágenes en ACR

```bash
# Login a ACR
az acr login --name <ACR_NAME>

# Construir y publicar RedeemService
docker build -f src/RedeemService/Dockerfile -t <ACR_NAME>.azurecr.io/redeem-service:latest .
docker push <ACR_NAME>.azurecr.io/redeem-service:latest

# Construir y publicar CampaignService
docker build -f src/CampaignService/Dockerfile -t <ACR_NAME>.azurecr.io/campaign-service:latest .
docker push <ACR_NAME>.azurecr.io/campaign-service:latest

# Construir y publicar CouponGenerator
docker build -f src/CouponGenerator/Dockerfile -t <ACR_NAME>.azurecr.io/coupon-generator:latest .
docker push <ACR_NAME>.azurecr.io/coupon-generator:latest
```

### 2. Actualizar manifiestos de Kubernetes

Reemplazar `<ACR_NAME>` en todos los archivos YAML con el nombre de tu ACR:

```bash
# En Windows PowerShell
(Get-Content k8s\redeem-service.yaml) -replace '<ACR_NAME>', 'your-acr-name' | Set-Content k8s\redeem-service.yaml
(Get-Content k8s\campaign-service.yaml) -replace '<ACR_NAME>', 'your-acr-name' | Set-Content k8s\campaign-service.yaml
```

### 3. Desplegar servicios en AKS

```bash
# Conectar a AKS
az aks get-credentials --resource-group <RESOURCE_GROUP> --name <AKS_NAME>

# Desplegar servicios
kubectl apply -f k8s/redeem-service.yaml
kubectl apply -f k8s/campaign-service.yaml
kubectl apply -f k8s/ingress.yaml

# Verificar despliegue
kubectl get pods
kubectl get services
kubectl get hpa
kubectl get ingress
```

### 4. Ejecutar job ACI (desde CampaignService)

El CampaignService lanzará contenedores ACI bajo demanda para generación masiva.

Configurar Azure SDK en CampaignService para crear Container Instances:

```bash
# Variables de entorno necesarias en CampaignService
AZURE_SUBSCRIPTION_ID=<subscription-id>
AZURE_RESOURCE_GROUP=<resource-group>
AZURE_ACI_LOCATION=<location>
ACR_NAME=<acr-name>
ACR_USERNAME=<acr-username>
ACR_PASSWORD=<acr-password>
```

## Verificación

### Probar endpoints

```bash
# Obtener IP del Ingress
kubectl get ingress coupons-ingress

# Probar canje de cupón
curl -X POST http://<INGRESS_IP>/api/redeem \
  -H "Content-Type: application/json" \
  -d '{"couponCode":"CUPON10OFF","userId":"user-12345"}'

# Probar consulta de cupón
curl http://<INGRESS_IP>/api/coupon/CUPON10OFF

# Probar generación masiva
curl -X POST http://<INGRESS_IP>/api/campaigns/CAMPAIGN-2025-BlackFriday/generate \
  -H "Content-Type: application/json" \
  -d '{"amount":50000,"prefix":"BF25"}'
```

## Monitoreo

```bash
# Ver logs de pods
kubectl logs -l app=redeem-service --tail=50
kubectl logs -l app=campaign-service --tail=50

# Ver métricas HPA
kubectl get hpa --watch

# Describir pods
kubectl describe pod <pod-name>
```

## Escalamiento Manual

```bash
# Escalar manualmente
kubectl scale deployment redeem-service --replicas=5
kubectl scale deployment campaign-service --replicas=3
```

## Actualización de Servicios

```bash
# Construir nueva versión
docker build -f src/RedeemService/Dockerfile -t <ACR_NAME>.azurecr.io/redeem-service:v2 .
docker push <ACR_NAME>.azurecr.io/redeem-service:v2

# Actualizar deployment
kubectl set image deployment/redeem-service redeem-service=<ACR_NAME>.azurecr.io/redeem-service:v2

# Ver estado del rollout
kubectl rollout status deployment/redeem-service

# Rollback si es necesario
kubectl rollout undo deployment/redeem-service
```

## Limpieza

```bash
# Eliminar todos los recursos
kubectl delete -f k8s/ingress.yaml
kubectl delete -f k8s/campaign-service.yaml
kubectl delete -f k8s/redeem-service.yaml
```
