#!/bin/bash

# Script para configurar ambos os serviços com ArgoCD no Minikube

set -e

echo "🚀 Setup de Service 1 e Service 2 com ArgoCD no Minikube"
echo "=========================================================="

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Verificar se minikube está rodando
echo -e "\n${YELLOW}Verificando Minikube...${NC}"
if ! minikube status &> /dev/null; then
    echo -e "${RED}Minikube não está rodando. Iniciando...${NC}"
    minikube start
else
    echo -e "${GREEN}✓ Minikube está rodando${NC}"
fi

# Verificar se ArgoCD já está instalado
echo -e "\n${YELLOW}Verificando ArgoCD...${NC}"
if ! kubectl get namespace argocd &> /dev/null; then
    echo -e "${YELLOW}Instalando ArgoCD...${NC}"
    kubectl create namespace argocd
    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    echo -e "${YELLOW}Aguardando ArgoCD inicializar...${NC}"
    kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
    echo -e "${GREEN}✓ ArgoCD instalado${NC}"
else
    echo -e "${GREEN}✓ ArgoCD já está instalado${NC}"
fi

# Aplicar manifests do Service 1
echo -e "\n${YELLOW}Aplicando manifests do Service 1...${NC}"
kubectl apply -f ../k8s/devops/

# Aplicar manifests do Service 2
echo -e "\n${YELLOW}Aplicando manifests do Service 2...${NC}"
kubectl apply -f ./devops/

# Aguardar pods iniciarem
echo -e "\n${YELLOW}Aguardando pods iniciarem...${NC}"
kubectl wait --for=condition=Ready pod -l app=meu-app --timeout=120s || true
kubectl wait --for=condition=Ready pod -l app=service-2 --timeout=120s || true

# Mostrar status
echo -e "\n${GREEN}=========================================================="
echo -e "Status dos Serviços${NC}"
echo "=========================================================="
kubectl get pods
echo ""
kubectl get svc

# Obter senha do ArgoCD
echo -e "\n${GREEN}=========================================================="
echo -e "Informações do ArgoCD${NC}"
echo "=========================================================="
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "N/A")

echo -e "ArgoCD UI: ${GREEN}http://localhost:8080${NC}"
echo -e "Username: ${GREEN}admin${NC}"
echo -e "Password: ${GREEN}${ARGOCD_PASSWORD}${NC}"

# URLs dos serviços
echo -e "\n${GREEN}=========================================================="
echo -e "URLs dos Serviços (use em terminais separados)${NC}"
echo "=========================================================="
echo -e "Para acessar o Service 1:"
echo -e "  ${YELLOW}minikube service meu-app-service --url${NC}"
echo -e "  ou"
echo -e "  ${YELLOW}kubectl port-forward svc/meu-app-service 8080:80${NC}"
echo ""
echo -e "Para acessar o Service 2:"
echo -e "  ${YELLOW}minikube service service-2-service --url${NC}"
echo -e "  ou"
echo -e "  ${YELLOW}kubectl port-forward svc/service-2-service 8081:80${NC}"
echo ""
echo -e "Para acessar o ArgoCD:"
echo -e "  ${YELLOW}kubectl port-forward svc/argocd-server -n argocd 8080:443${NC}"

# Testar comunicação
echo -e "\n${GREEN}=========================================================="
echo -e "Comandos para testar a comunicação${NC}"
echo "=========================================================="
echo -e "Depois de fazer port-forward do Service 2 na porta 8081:"
echo -e "  ${YELLOW}curl http://localhost:8081/${NC}"
echo -e "  ${YELLOW}curl http://localhost:8081/health${NC}"
echo -e "  ${YELLOW}curl http://localhost:8081/call-service1${NC}"
echo -e "  ${YELLOW}curl http://localhost:8081/chain${NC}"

# Logs
echo -e "\n${GREEN}=========================================================="
echo -e "Comandos para ver logs${NC}"
echo "=========================================================="
echo -e "Service 1: ${YELLOW}kubectl logs -l app=meu-app -f${NC}"
echo -e "Service 2: ${YELLOW}kubectl logs -l app=service-2 -f${NC}"

echo -e "\n${GREEN}✅ Setup completo!${NC}"

