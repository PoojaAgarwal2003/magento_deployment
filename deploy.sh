#!/bin/bash

set -e

# Define variables
FLEX_SERVER_NAME="magento-mysql-66f3qbnqyel5s.mysql.database.azure.com"
AZURE_STORAGE_ACCOUNT_NAME="magentofs66f3qbnqyel5s"
AZURE_STORAGE_ACCOUNT_KEY="IRgCDva3MhNxyaFsGtbOPSfryZ2jUJBC8kc/bLlh5RNdTNX5iPoClL8HD7RSZ42fWdRuv2uQTVZL+AStmWq6ow=="
FLEX_SERVER_USER="pooja"
FLEX_SERVER_PASSWORD="Pooja@1234"

export KUBECONFIG=$(pwd)/kubeconfig

# Create Azure Secret
echo "Creating Azure Secret"
kubectl create secret generic azure-secret \
  --from-literal=azurestorageaccountname=$AZURE_STORAGE_ACCOUNT_NAME \
  --from-literal=azurestorageaccountkey=$AZURE_STORAGE_ACCOUNT_KEY 

# Deploy Persistent Volume and Persistent Volume Claim
echo "Deploying Persistent Volume"
kubectl apply -f k8s/pv.yaml

echo "Deploying Persistent Volume Claim"
kubectl apply -f k8s/pvc.yaml

# Deploy Services
echo "Deploying Elasticsearch Service"
kubectl apply -f k8s/elasticsearch-service.yaml

echo "Deploying Magento Service"
kubectl apply -f k8s/magento-service.yaml

# Function to get the external IP of the service
get_external_ip() {
    local service_name=$1
    kubectl get service $service_name --output jsonpath='{.status.loadBalancer.ingress[0].ip}'
}

# Retrieve the external IP of Magento service
external_ip=""
while [ -z "$external_ip" ]; do
    echo "Waiting for external IP..."
    external_ip=$(get_external_ip "magento")
    if [ -z "$external_ip" ]; then
        sleep 10
    fi
done

echo "External IP found: $external_ip"

# Create ConfigMap
echo "Creating ConfigMap"
kubectl create configmap magento-config \
  --from-literal=MAGENTO_BASE_URL=http://$external_ip \
  --from-literal=NGINX_SERVER_NAME=$external_ip \
  --from-literal=FLEX_SERVER_NAME=$FLEX_SERVER_NAME \
  --from-literal=FLEX_SERVER_USER=$FLEX_SERVER_USER \
  --from-literal=FLEX_SERVER_PASSWORD=$FLEX_SERVER_PASSWORD

# Deploy Elasticsearch and Magento Deployments
echo "Deploying Elasticsearch"
kubectl apply -f k8s/elasticsearch-deployment.yaml

echo "Deploying Magento"
kubectl apply -f k8s/magento-deployment.yaml

echo "Deployment Complete"
