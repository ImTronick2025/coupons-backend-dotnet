# Checklist de Pre-Despliegue a AKS

## ✅ Estado de Preparación: CASI LISTO

### 📦 Componentes Listos

| Componente | Estado | Detalles |
|------------|--------|----------|
| Dockerfiles | ✅ | Multi-stage builds optimizados |
| RedeemService | ✅ | Código completo y funcional |
| CampaignService | ✅ | Código completo y funcional |
| Shared.Models | ✅ | DTOs compartidos |
| K8s Manifests | ⚠️ | Requieren simplificación |
| Health Checks | ✅ | Implementados en ambos servicios |
| Logging | ✅ | ILogger configurado |

### ⚠️ Ajustes Necesarios

1. **Simplificar manifiestos K8s**
   - Remover referencias a SQL Database (no usado aún)
   - Remover referencias a Key Vault (no usado aún)
   - Usar configuración in-memory para primera versión

2. **Variables de entorno básicas**
   - Solo `ASPNETCORE_ENVIRONMENT` y `ASPNETCORE_URLS`

3. **Health checks correctos**
   - RedeemService: `/api/health`
   - CampaignService: `/api/campaigns/health`

### 📋 Pre-requisitos de Azure

Antes de desplegar, necesitas:

- [ ] **Azure Container Registry (ACR)** creado
- [ ] **Azure Kubernetes Service (AKS)** cluster creado
- [ ] **ACR vinculado a AKS** (`az aks update --attach-acr`)
- [ ] **kubectl** configurado con credenciales de AKS
- [ ] **NGINX Ingress Controller** instalado en AKS

### 🔧 Comandos de Verificación

```bash
# Verificar ACR
az acr list -o table

# Verificar AKS
az aks list -o table

# Verificar conexión kubectl
kubectl get nodes

# Verificar NGINX Ingress
kubectl get pods -n ingress-nginx
```

---

## 🚀 Plan de Despliegue

### Fase 1: Construcción de Imágenes
1. Build y push RedeemService a ACR
2. Build y push CampaignService a ACR
3. Verificar imágenes en ACR

### Fase 2: Despliegue a AKS
1. Aplicar manifiestos simplificados
2. Verificar pods corriendo
3. Verificar servicios creados

### Fase 3: Configurar Ingress
1. Aplicar Ingress NGINX
2. Obtener IP pública
3. Probar endpoints

### Fase 4: Pruebas
1. Health checks
2. Consultar cupón
3. Canjear cupón
4. Solicitar generación

---

## 📝 Información Requerida

Para completar el despliegue, necesito que me proporciones:

1. **Nombre de ACR**: `<ACR_NAME>` (ej: couponssacr)
2. **Nombre de AKS**: `<AKS_NAME>` (ej: coupons-aks)
3. **Resource Group**: `<RESOURCE_GROUP>` (ej: rg-coupons)
4. **Región**: `<LOCATION>` (ej: eastus)

---

## ⚡ Próximos Pasos

1. Proporcionar nombres de recursos Azure
2. Crear manifiestos K8s simplificados
3. Script de deploy automatizado
4. Ejecutar despliegue
5. Probar servicios en AKS
