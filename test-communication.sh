#!/bin/bash

# Script para testar a comunicação entre os serviços

set -e

echo "🧪 Testando comunicação entre Service 1 e Service 2"
echo "===================================================="

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para testar endpoint
test_endpoint() {
    local url=$1
    local description=$2
    
    echo -e "\n${YELLOW}Testando: ${description}${NC}"
    echo "URL: $url"
    echo "----------------------------------------"
    
    response=$(curl -s -w "\n\nHTTP Status: %{http_code}" "$url" 2>&1) || {
        echo -e "${RED}✗ Falha na requisição${NC}"
        echo "$response"
        return 1
    }
    
    echo "$response"
    
    if echo "$response" | grep -q "HTTP Status: 200"; then
        echo -e "${GREEN}✓ Sucesso!${NC}"
        return 0
    else
        echo -e "${RED}✗ Falhou${NC}"
        return 1
    fi
}

# Verificar se os serviços estão rodando
echo -e "${YELLOW}Verificando se os pods estão rodando...${NC}"
kubectl get pods -l app=meu-app
kubectl get pods -l app=service-2

# Opção 1: Usar minikube service URLs
echo -e "\n${YELLOW}Método 1: Usando minikube service URLs${NC}"
echo "========================================"

SERVICE1_URL=$(minikube service meu-app-service --url 2>/dev/null || echo "")
SERVICE2_URL=$(minikube service service-2-service --url 2>/dev/null || echo "")

if [ -n "$SERVICE1_URL" ] && [ -n "$SERVICE2_URL" ]; then
    echo -e "Service 1 URL: ${GREEN}$SERVICE1_URL${NC}"
    echo -e "Service 2 URL: ${GREEN}$SERVICE2_URL${NC}"
    
    test_endpoint "$SERVICE1_URL" "Service 1 - Root endpoint"
    test_endpoint "$SERVICE1_URL/health" "Service 1 - Health check"
    test_endpoint "$SERVICE2_URL" "Service 2 - Root endpoint"
    test_endpoint "$SERVICE2_URL/health" "Service 2 - Health check"
    test_endpoint "$SERVICE2_URL/call-service1" "Service 2 chamando Service 1"
    test_endpoint "$SERVICE2_URL/chain" "Service 2 - Chain de chamadas"
else
    echo -e "${RED}Não foi possível obter URLs do minikube service${NC}"
    echo -e "${YELLOW}Tentando método alternativo...${NC}"
fi

# Opção 2: Testar de dentro do cluster
echo -e "\n${YELLOW}Método 2: Testando de dentro do cluster${NC}"
echo "========================================"

SERVICE2_POD=$(kubectl get pod -l app=service-2 -o jsonpath="{.items[0].metadata.name}" 2>/dev/null || echo "")

if [ -n "$SERVICE2_POD" ]; then
    echo -e "Pod do Service 2: ${GREEN}$SERVICE2_POD${NC}"
    
    echo -e "\n${YELLOW}Testando DNS e conectividade do Service 1...${NC}"
    kubectl exec $SERVICE2_POD -- wget -qO- http://meu-app-service 2>&1 || echo "Falha ao conectar"
    
    echo -e "\n${YELLOW}Testando endpoint /call-service1 de dentro do pod...${NC}"
    kubectl exec $SERVICE2_POD -- wget -qO- http://localhost:3001/call-service1 2>&1 || echo "Falha ao conectar"
else
    echo -e "${RED}Pod do Service 2 não encontrado${NC}"
fi

# Mostrar logs recentes
echo -e "\n${YELLOW}Logs recentes do Service 2:${NC}"
echo "========================================"
kubectl logs -l app=service-2 --tail=20

echo -e "\n${GREEN}Testes concluídos!${NC}"
echo -e "\n${YELLOW}Para testes manuais, use:${NC}"
echo "1. Terminal 1: kubectl port-forward svc/service-2-service 8081:80"
echo "2. Terminal 2: curl http://localhost:8081/call-service1"

