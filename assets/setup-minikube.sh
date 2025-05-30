#!/bin/bash
set -euo pipefail

# Function to check command status
check_status() {
    echo "✔️  $1 succeeded"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 1. Check for NVIDIA GPU
echo "🔍 Checking for NVIDIA GPU support..."
if ! command_exists nvidia-smi; then
    echo "⚠️  nvidia-smi not found. GPU support may be unavailable."
else
    nvidia-smi
    check_status "nvidia-smi"
fi

# 2. Install Minikube if needed
echo "🔍 Checking for Minikube..."
if ! command_exists minikube; then
    echo "⬇️  Installing Minikube..."
    curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    chmod +x minikube
    sudo mv minikube /usr/local/bin/
    check_status "Minikube installation"
else
    echo "✅ Minikube already installed"
fi

# 3. Install kubectl if needed
echo "🔍 Checking for kubectl..."
if ! command_exists kubectl; then
    echo "⬇️  Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    check_status "kubectl installation"
else
    echo "✅ kubectl already installed"
fi

# 4. Start Minikube
echo "🚀 Starting Minikube (Docker driver)..."
minikube start --driver=docker --addons=default-storageclass
check_status "minikube start"

# 5. Enable NVIDIA GPU addons (if GPU exists)
if command_exists nvidia-smi; then
    echo "🔌 Enabling NVIDIA device-plugin and driver-installer addons..."
    minikube addons enable nvidia-driver-installer
    minikube addons enable nvidia-gpu-device-plugin
    check_status "NVIDIA addons"
fi

# 6. Verify cluster health
echo "🔍 Verifying cluster status..."
kubectl get nodes
check_status "kubectl get nodes"

# 7. Deploy a sample application
echo "📦 Deploying test NGINX application..."
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml | kubectl apply -f -
kubectl rollout status deployment/nginx
kubectl get pods
check_status "NGINX deployment"

# 8. Configure Helm repository for NVIDIA
echo "🎯 Configuring Helm for NVIDIA charts..."
if ! command_exists helm; then
    echo "⬇️  Installing Helm..."
    curl -Lo helm.tar.gz https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz
    tar -zxvf helm.tar.gz linux-amd64/helm
    sudo mv linux-amd64/helm /usr/local/bin/
    rm -rf linux-amd64 helm.tar.gz
    check_status "Helm installation"
fi

helm repo remove nvidia >/dev/null 2>&1 || true
helm repo add nvidia https://helm.ngc.nvidia.com/nvidia
helm repo update
check_status "Helm repo update"

# 9. Create NGC registry secret
echo "🔐 Creating Docker registry secret for NGC..."
kubectl create secret docker-registry ngc-secret \
  --docker-server=nvcr.io \
  --docker-username='$oauthtoken' \
  --docker-password="$NGC_API_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -
check_status "NGC registry secret"

echo "🎉 Minikube setup complete! You can now use kubectl and helm against your cluster."
