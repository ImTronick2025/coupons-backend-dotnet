# Backend - Configuración de CI/CD

## Secretos Requeridos en GitHub

Para que el workflow funcione correctamente, debes configurar los siguientes secretos en tu repositorio de GitHub:

### 1. AZURE_CREDENTIALS

Credenciales del Service Principal de Azure:

```bash
az ad sp create-for-rbac --name "github-actions-coupons-backend" \
  --role contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP> \
  --sdk-auth
```

Copia el JSON completo y agrégalo como secreto `AZURE_CREDENTIALS`.

### 2. ACR_NAME

Nombre de tu Azure Container Registry (solo el nombre, sin `.azurecr.io`):

```
Ejemplo: mycouponsacr
```

### 3. AZURE_RESOURCE_GROUP

Nombre del grupo de recursos donde están tus recursos de Azure:

```
Ejemplo: rg-coupons-prod
```

### 4. AKS_CLUSTER_NAME

Nombre de tu cluster de Azure Kubernetes Service:

```
Ejemplo: aks-coupons-prod
```

## Configurar Secretos

1. Ve a tu repositorio en GitHub
2. Settings > Secrets and variables > Actions
3. Click en "New repository secret"
4. Agrega cada secreto mencionado arriba

## Workflow Triggers

El workflow se ejecuta en:

- **Push a main**: Build + Test + Push imágenes + Deploy a AKS
- **Push a develop**: Build + Test + Push imágenes
- **Pull Request a main**: Build + Test
- **Manual**: Workflow dispatch

## Verificar Despliegue

Después de un push exitoso a `main`:

```bash
# Ver estado de los pods
kubectl get pods

# Ver logs
kubectl logs -l app=redeem-service --tail=50
kubectl logs -l app=campaign-service --tail=50

# Probar endpoints
kubectl get ingress
curl http://<INGRESS_IP>/api/health
```

## Troubleshooting

### Error de autenticación ACR

```bash
# Verificar que AKS puede acceder a ACR
az aks update -n <AKS_NAME> -g <RESOURCE_GROUP> --attach-acr <ACR_NAME>
```

### Error de permisos de Service Principal

```bash
# Dar permisos adicionales al Service Principal
az role assignment create \
  --assignee <SERVICE_PRINCIPAL_ID> \
  --role "AcrPush" \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>/providers/Microsoft.ContainerRegistry/registries/<ACR_NAME>
```
