# Arquitetura - Comunicação entre Microservices

## Visão Geral

Este projeto demonstra comunicação entre dois microservices Node.js rodando no Kubernetes:

```
┌─────────────────────────────────────────────────────────────┐
│                         Kubernetes Cluster                   │
│                                                              │
│  ┌────────────────────────┐    ┌─────────────────────────┐ │
│  │      Service 2         │    │       Service 1         │ │
│  │    (Port 3001)         │───▶│      (Port 3000)        │ │
│  │                        │    │                         │ │
│  │  Endpoints:            │    │  Endpoints:             │ │
│  │  - /                   │    │  - /                    │ │
│  │  - /health             │    │  - /health              │ │
│  │  - /call-service1  ⭐  │    │                         │ │
│  │  - /chain          ⭐  │    │                         │ │
│  └────────────────────────┘    └─────────────────────────┘ │
│           │                              │                  │
│           │                              │                  │
│  ┌────────▼──────────────┐    ┌─────────▼────────────────┐ │
│  │  service-2-service    │    │   meu-app-service        │ │
│  │  LoadBalancer         │    │   LoadBalancer           │ │
│  │  Port: 80→3001        │    │   Port: 80→3000          │ │
│  └───────────────────────┘    └──────────────────────────┘ │
│           │                              │                  │
└───────────┼──────────────────────────────┼──────────────────┘
            │                              │
            ▼                              ▼
       External Access                External Access
     (via LoadBalancer)             (via LoadBalancer)
```

## Componentes

### Service 1 (k8s)
- **Tecnologia**: Node.js + Express
- **Porta**: 3000
- **Função**: Serviço básico que retorna informações do host
- **Endpoints**:
  - `GET /` - Retorna mensagem, timestamp e hostname
  - `GET /health` - Health check

### Service 2 (2service)
- **Tecnologia**: Node.js + Express + Axios
- **Porta**: 3001
- **Função**: Serviço que consome o Service 1
- **Endpoints**:
  - `GET /` - Retorna informações básicas do Service 2
  - `GET /health` - Health check do Service 2
  - `GET /call-service1` - Chama Service 1 e combina respostas
  - `GET /chain` - Faz múltiplas chamadas paralelas ao Service 1

## Comunicação entre Serviços

### DNS do Kubernetes
Os serviços se comunicam através do DNS interno do Kubernetes:

- **Service Name**: `meu-app-service`
- **Full DNS**: `meu-app-service.default.svc.cluster.local`
- **Short DNS**: `meu-app-service` (mesmo namespace)

### Fluxo de Comunicação

1. **Requisição Externa** → Service 2
   ```
   Client → LoadBalancer (service-2-service) → Pod Service 2
   ```

2. **Service 2 → Service 1** (Comunicação Interna)
   ```
   Pod Service 2 → meu-app-service (ClusterIP) → Pod Service 1
   ```

3. **Resposta Combinada**
   ```
   Pod Service 1 → Pod Service 2 → Client
   ```

## Recursos Kubernetes

### Deployments

#### Service 1: `meu-app`
```yaml
replicas: 1
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

#### Service 2: `service-2`
```yaml
replicas: 1
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
env:
  - SERVICE1_URL: http://meu-app-service
```

### Services

#### Service 1: `meu-app-service`
- **Type**: LoadBalancer
- **Port**: 80
- **TargetPort**: 3000
- **Selector**: app=meu-app

#### Service 2: `service-2-service`
- **Type**: LoadBalancer
- **Port**: 80
- **TargetPort**: 3001
- **Selector**: app=service-2

### ConfigMaps
Cada serviço tem seu próprio ConfigMap para configurações:
- `meu-config` (Service 1)
- `service-2-config` (Service 2)

### Service Accounts
Cada serviço tem seu próprio Service Account:
- `meu-sa` (Service 1)
- `service-2-sa` (Service 2)

### Horizontal Pod Autoscaler (HPA)
Ambos os serviços têm HPA configurado:
- **Min Replicas**: 1
- **Max Replicas**: 5
- **Target CPU**: 70%
- **Target Memory**: 80%

## Padrões de Comunicação Implementados

### 1. Service Discovery
Usando DNS do Kubernetes para descobrir serviços:
```javascript
const SERVICE1_URL = process.env.SERVICE1_URL || 'http://meu-app-service';
```

### 2. Health Checks
Ambos os serviços implementam `/health` endpoint:
- Liveness Probe
- Readiness Probe

### 3. Error Handling
Tratamento de erros na comunicação:
```javascript
try {
  const response = await axios.get(SERVICE1_URL, { timeout: 5000 });
  // ... processo response
} catch (error) {
  // ... handle error
}
```

### 4. Timeout Configuration
Timeout de 5 segundos para evitar requests infinitos:
```javascript
axios.get(SERVICE1_URL, { timeout: 5000 })
```

### 5. Parallel Requests
Uso de `Promise.all` para requisições paralelas:
```javascript
const calls = await Promise.all([
  axios.get(SERVICE1_URL),
  axios.get(`${SERVICE1_URL}/health`)
]);
```

## CI/CD Pipeline

### GitHub Actions Workflow

1. **Trigger**: Push para branch `main`
2. **Build**: Cria imagem Docker
3. **Push**: Envia para Docker Hub
4. **Update**: Atualiza manifest com nova tag (commit SHA)
5. **GitOps**: ArgoCD detecta mudança e faz deploy

### ArgoCD
- **Sync Policy**: Automated
- **Self Heal**: Enabled
- **Prune**: Enabled
- **Source**: Git repository
- **Path**: `devops/`

## Segurança

### Service Accounts
Cada serviço roda com seu próprio Service Account, seguindo o princípio de least privilege.

### Network Policies (Opcional)
Pode-se adicionar NetworkPolicies para controlar:
- Ingress: Quem pode acessar cada serviço
- Egress: Quais serviços podem ser acessados

Exemplo:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: service-2-policy
spec:
  podSelector:
    matchLabels:
      app: service-2
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: meu-app
```

## Observabilidade

### Logs
Logs estruturados com informações de contexto:
```javascript
console.log(`Calling service 1 at ${SERVICE1_URL}`);
```

### Metrics
Prometheus pode ser configurado para coletar métricas:
- Request count
- Response time
- Error rate

### Tracing (Futuro)
Pode-se adicionar distributed tracing com:
- Jaeger
- Zipkin
- OpenTelemetry

## Testes

### Smoke Tests
```bash
curl http://service-2/call-service1
```

### Load Tests
```bash
kubectl run -it --rm load-test --image=busybox --restart=Never -- /bin/sh -c "while true; do wget -O- http://service-2-service/call-service1; done"
```

### Chaos Testing
Usar Chaos Mesh ou similar para testar resiliência:
- Pod deletion
- Network latency
- Resource limits

## Próximas Melhorias

1. **Circuit Breaker**: Implementar com resilience4j ou similar
2. **Rate Limiting**: Adicionar rate limiting nos endpoints
3. **Caching**: Implementar cache para reduzir chamadas
4. **Service Mesh**: Usar Istio ou Linkerd para features avançadas
5. **API Gateway**: Adicionar Kong ou similar como ponto de entrada único
6. **Autenticação**: Implementar mTLS ou JWT
7. **Tracing**: Adicionar distributed tracing
8. **Metrics**: Expor métricas do Prometheus

## Referências

- [Kubernetes Service Discovery](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Kubernetes DNS](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Express.js](https://expressjs.com/)
- [Axios](https://axios-http.com/)

