# Service 2 - Microservice Communication Demo

Este é o segundo serviço que demonstra comunicação entre microservices no Kubernetes.

## Funcionalidades

- **GET `/`** - Retorna informações básicas do Service 2
- **GET `/health`** - Health check endpoint
- **GET `/call-service1`** - Chama o Service 1 e retorna a resposta combinada
- **GET `/chain`** - Faz múltiplas chamadas ao Service 1 em paralelo

## Comunicação com Service 1

O Service 2 se comunica com o Service 1 através do DNS interno do Kubernetes usando o nome do serviço `meu-app-service`. A URL é configurável através da variável de ambiente `SERVICE1_URL`.

## Desenvolvimento Local

```bash
# Instalar dependências
npm install

# Executar o servidor
npm start
```

## Build Docker

```bash
docker build -t renaneiras/service-2:latest .
docker push renaneiras/service-2:latest
```

## Deploy no Kubernetes

### Aplicar todos os manifests

```bash
kubectl apply -f devops/
```

### Verificar os pods

```bash
kubectl get pods -l app=service-2
kubectl logs -l app=service-2 -f
```

### Testar a comunicação

```bash
# Obter a URL do serviço (minikube)
minikube service service-2-service --url

# Testar endpoints
curl http://<service-url>/
curl http://<service-url>/health
curl http://<service-url>/call-service1
curl http://<service-url>/chain
```

## Setup com Minikube e ArgoCD

### 1. Iniciar Minikube

```bash
minikube start
```

### 2. Instalar ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Aguardar os pods iniciarem
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Acessar ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Obter senha inicial
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 3. Criar Application no ArgoCD para ambos os serviços

#### Service 1 (k8s)
```bash
argocd app create service-1 \
  --repo https://github.com/seu-usuario/k8s.git \
  --path devops \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated
```

#### Service 2
```bash
argocd app create service-2 \
  --repo https://github.com/seu-usuario/2service.git \
  --path devops \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default \
  --sync-policy automated
```

### 4. Verificar a comunicação entre serviços

```bash
# Port-forward do Service 2
kubectl port-forward svc/service-2-service 8081:80

# Em outro terminal, testar a comunicação
curl http://localhost:8081/call-service1
curl http://localhost:8081/chain
```

### 5. Monitorar logs

```bash
# Service 1
kubectl logs -l app=meu-app -f

# Service 2
kubectl logs -l app=service-2 -f
```

## Arquitetura

```
┌─────────────┐         ┌─────────────┐
│             │         │             │
│  Service 2  │────────>│  Service 1  │
│  (port 3001)│         │  (port 3000)│
│             │         │             │
└─────────────┘         └─────────────┘
      │                       │
      │                       │
      v                       v
  LoadBalancer           LoadBalancer
  service-2-service      meu-app-service
```

## Variáveis de Ambiente

- `SERVICE1_URL`: URL do Service 1 (default: `http://meu-app-service`)
- `LOG_LEVEL`: Nível de log (configurado via ConfigMap)

## CI/CD

O projeto usa GitHub Actions para:
1. Build da imagem Docker
2. Push para Docker Hub
3. Atualização automática do manifests com a nova tag
4. ArgoCD detecta mudanças e faz deploy automático

## Troubleshooting

### Service 2 não consegue alcançar Service 1

```bash
# Verificar se o Service 1 está rodando
kubectl get svc meu-app-service
kubectl get pods -l app=meu-app

# Testar DNS do dentro do pod
kubectl exec -it <service-2-pod> -- nslookup meu-app-service
kubectl exec -it <service-2-pod> -- wget -O- http://meu-app-service
```

### Ver logs de erros

```bash
kubectl logs -l app=service-2 --tail=100
kubectl describe pod -l app=service-2
```

