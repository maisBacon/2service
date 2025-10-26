# 🚀 Quick Start - Testando no Minikube

Este guia rápido vai te colocar para rodar ambos os serviços em menos de 5 minutos!

## Passo 1: Preparar ambiente

```bash
# Iniciar Minikube
minikube start

# Configurar Docker para usar o daemon do Minikube
eval $(minikube docker-env)
```

## Passo 2: Build das imagens localmente

```bash
# Build Service 1
cd /Users/renanmelo/Projects/Lab/k8s
docker build -t renaneiras/meu-app:local .

# Build Service 2
cd /Users/renanmelo/Projects/Lab/2service
docker build -t renaneiras/service-2:local .
```

## Passo 3: Deploy no Kubernetes

```bash
# Aplicar manifests do Service 1
kubectl apply -f /Users/renanmelo/Projects/Lab/k8s/devops/

# Aplicar manifests do Service 2
kubectl apply -f /Users/renanmelo/Projects/Lab/2service/devops/

# Aguardar pods iniciarem
kubectl wait --for=condition=Ready pod -l app=meu-app --timeout=60s
kubectl wait --for=condition=Ready pod -l app=service-2 --timeout=60s
```

## Passo 4: Verificar status

```bash
kubectl get pods
kubectl get svc
```

## Passo 5: Testar a comunicação

### Opção A: Port Forward (Recomendado)

```bash
# Terminal 1
kubectl port-forward svc/service-2-service 8081:80

# Terminal 2 - Execute os testes
curl http://localhost:8081/
curl http://localhost:8081/health
curl http://localhost:8081/call-service1
curl http://localhost:8081/chain
```

### Opção B: Usar script automático

```bash
cd /Users/renanmelo/Projects/Lab/2service
./test-communication.sh
```

## Passo 6 (Opcional): Setup com ArgoCD

```bash
cd /Users/renanmelo/Projects/Lab/2service
./setup-argocd.sh
```

## Comandos Úteis

### Ver logs em tempo real
```bash
# Service 1
kubectl logs -l app=meu-app -f

# Service 2
kubectl logs -l app=service-2 -f
```

### Acessar shell do pod
```bash
kubectl exec -it $(kubectl get pod -l app=service-2 -o jsonpath="{.items[0].metadata.name}") -- sh
```

### Testar de dentro do cluster
```bash
# Entrar no pod do Service 2
kubectl exec -it $(kubectl get pod -l app=service-2 -o jsonpath="{.items[0].metadata.name}") -- sh

# Dentro do pod, testar:
wget -qO- http://meu-app-service/
wget -qO- http://localhost:3001/call-service1
```

## Endpoints Disponíveis

### Service 1 (porta 3000)
- `GET /` - Info básica
- `GET /health` - Health check

### Service 2 (porta 3001)
- `GET /` - Info básica
- `GET /health` - Health check
- `GET /call-service1` - ⭐ Chama o Service 1 e combina respostas
- `GET /chain` - ⭐ Faz múltiplas chamadas ao Service 1

## Limpeza

```bash
# Deletar tudo
kubectl delete -f /Users/renanmelo/Projects/Lab/k8s/devops/
kubectl delete -f /Users/renanmelo/Projects/Lab/2service/devops/

# Ou parar o Minikube
minikube stop
```

## Próximos Passos

1. Veja `TESTING.md` para testes mais detalhados
2. Veja `README.md` para documentação completa
3. Configure GitHub Actions para CI/CD automático
4. Configure ArgoCD para GitOps

## Troubleshooting Rápido

**Pods não iniciam?**
```bash
kubectl describe pod -l app=service-2
kubectl logs -l app=service-2
```

**Imagem não encontrada?**
```bash
# Certifique-se de usar o Docker do Minikube
eval $(minikube docker-env)
# Rebuild a imagem
docker build -t renaneiras/service-2:local .
# Force restart
kubectl rollout restart deployment/service-2
```

**Service 2 não alcança Service 1?**
```bash
# Verificar se Service 1 está rodando
kubectl get pods -l app=meu-app
kubectl get svc meu-app-service

# Testar DNS de dentro do pod
kubectl exec -it $(kubectl get pod -l app=service-2 -o jsonpath="{.items[0].metadata.name}") -- nslookup meu-app-service
```

