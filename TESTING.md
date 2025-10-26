# Guia de Testes - Service 1 e Service 2

Este guia mostra como testar a comunicação entre os dois serviços no Minikube com ArgoCD.

## Pré-requisitos

- Minikube instalado
- kubectl configurado
- Docker instalado (para build das imagens)

## Setup Rápido

### 1. Build das imagens Docker localmente (para testes rápidos no Minikube)

```bash
# Build do Service 1
cd /Users/renanmelo/Projects/Lab/k8s
eval $(minikube docker-env)
docker build -t renaneiras/meu-app:local .

# Build do Service 2
cd /Users/renanmelo/Projects/Lab/2service
eval $(minikube docker-env)
docker build -t renaneiras/service-2:local .
```

### 2. Atualizar os deployments para usar imagens locais (temporário para testes)

```bash
# Service 1
cd /Users/renanmelo/Projects/Lab/k8s
kubectl set image deployment/meu-app meu-app=renaneiras/meu-app:local

# Service 2
cd /Users/renanmelo/Projects/Lab/2service
kubectl set image deployment/service-2 service-2=renaneiras/service-2:local
```

### 3. Executar o script de setup

```bash
cd /Users/renanmelo/Projects/Lab/2service
./setup-argocd.sh
```

### 4. Executar os testes de comunicação

```bash
./test-communication.sh
```

## Testes Manuais Detalhados

### Método 1: Port Forward (Recomendado)

#### Terminal 1 - Service 1
```bash
kubectl port-forward svc/meu-app-service 8080:80
```

#### Terminal 2 - Service 2
```bash
kubectl port-forward svc/service-2-service 8081:80
```

#### Terminal 3 - Testes
```bash
# Testar Service 1 diretamente
curl http://localhost:8080/
curl http://localhost:8080/health

# Testar Service 2 diretamente
curl http://localhost:8081/
curl http://localhost:8081/health

# Testar Service 2 chamando Service 1
curl http://localhost:8081/call-service1

# Testar chamadas em cadeia
curl http://localhost:8081/chain
```

### Método 2: Minikube Service

```bash
# Abrir Service 1 no browser
minikube service meu-app-service

# Abrir Service 2 no browser
minikube service service-2-service

# Ou obter URLs
SERVICE1_URL=$(minikube service meu-app-service --url)
SERVICE2_URL=$(minikube service service-2-service --url)

# Testar
curl $SERVICE2_URL/call-service1
curl $SERVICE2_URL/chain
```

### Método 3: De dentro do cluster

```bash
# Entrar no pod do Service 2
SERVICE2_POD=$(kubectl get pod -l app=service-2 -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it $SERVICE2_POD -- sh

# De dentro do pod, testar:
wget -qO- http://localhost:3001/
wget -qO- http://localhost:3001/call-service1
wget -qO- http://meu-app-service/
```

## Verificações de Status

### Verificar Pods

```bash
# Ver todos os pods
kubectl get pods

# Ver pods específicos
kubectl get pods -l app=meu-app
kubectl get pods -l app=service-2

# Detalhes de um pod
kubectl describe pod -l app=service-2
```

### Verificar Services

```bash
# Ver todos os services
kubectl get svc

# Ver endpoints
kubectl get endpoints meu-app-service
kubectl get endpoints service-2-service
```

### Verificar Logs

```bash
# Service 1
kubectl logs -l app=meu-app -f

# Service 2
kubectl logs -l app=service-2 -f

# Todos os logs de um pod específico
kubectl logs <pod-name> --all-containers
```

## Testando com ArgoCD

### 1. Acessar ArgoCD UI

```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Obter senha
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Acessar: https://localhost:8080
# Username: admin
# Password: <senha obtida acima>
```

### 2. Criar Applications via UI ou CLI

#### Via CLI (se tiver argocd CLI instalado)

```bash
# Instalar ArgoCD CLI (macOS)
brew install argocd

# Login
argocd login localhost:8080

# Criar app para Service 1
argocd app create service-1 \
  --repo https://github.com/renaneiras/k8s.git \
  --path devops \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated

# Criar app para Service 2
argocd app create service-2 \
  --repo https://github.com/renaneiras/2service.git \
  --path devops \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated
```

#### Via Manifest YAML

```bash
# Aplicar o manifest do ArgoCD App
kubectl apply -f argocd-app.yaml

# Fazer o mesmo para o Service 1 (criar um argocd-app.yaml lá também)
```

## Exemplos de Respostas Esperadas

### Service 1 Root (/)
```json
{
  "message": "Hello from Kubernetes!!!! ",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "hostname": "meu-app-xxx"
}
```

### Service 2 Root (/)
```json
{
  "message": "Hello from Service 2!",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "hostname": "service-2-xxx",
  "service": "service-2"
}
```

### Service 2 chamando Service 1 (/call-service1)
```json
{
  "message": "Successfully called Service 1",
  "service2Info": {
    "hostname": "service-2-xxx",
    "timestamp": "2024-01-01T12:00:00.000Z"
  },
  "service1Response": {
    "message": "Hello from Kubernetes!!!! ",
    "timestamp": "2024-01-01T12:00:00.000Z",
    "hostname": "meu-app-xxx"
  }
}
```

### Service 2 Chain (/chain)
```json
{
  "message": "Chain of calls completed",
  "service2": {
    "hostname": "service-2-xxx",
    "timestamp": "2024-01-01T12:00:00.000Z"
  },
  "service1Root": {
    "message": "Hello from Kubernetes!!!! ",
    "timestamp": "2024-01-01T12:00:00.000Z",
    "hostname": "meu-app-xxx"
  },
  "service1Health": {
    "status": "healthy"
  }
}
```

## Troubleshooting

### Service 2 não consegue conectar ao Service 1

1. Verificar se ambos os services estão rodando:
```bash
kubectl get svc
kubectl get pods
```

2. Testar DNS de dentro do pod:
```bash
kubectl exec -it <service-2-pod> -- nslookup meu-app-service
```

3. Testar conectividade:
```bash
kubectl exec -it <service-2-pod> -- wget -qO- http://meu-app-service
```

### Pods em CrashLoopBackOff

```bash
# Ver logs
kubectl logs <pod-name>

# Ver eventos
kubectl describe pod <pod-name>

# Verificar recursos
kubectl top pods
```

### Imagem não encontrada

Se estiver usando imagens locais, certifique-se de:

1. Usar o Docker do Minikube:
```bash
eval $(minikube docker-env)
```

2. Fazer rebuild:
```bash
docker build -t renaneiras/service-2:local .
```

3. Atualizar deployment:
```bash
kubectl set image deployment/service-2 service-2=renaneiras/service-2:local
kubectl rollout restart deployment/service-2
```

### NetworkPolicy bloqueando comunicação

Se estiver usando NetworkPolicies, verifique:
```bash
kubectl get networkpolicies
kubectl describe networkpolicy <policy-name>
```

## Limpeza

```bash
# Deletar resources
kubectl delete -f /Users/renanmelo/Projects/Lab/k8s/devops/
kubectl delete -f /Users/renanmelo/Projects/Lab/2service/devops/

# Deletar ArgoCD (opcional)
kubectl delete namespace argocd

# Parar Minikube
minikube stop

# Deletar cluster Minikube (se quiser começar do zero)
minikube delete
```

