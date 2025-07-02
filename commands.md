# Istio Demo Commands

## Prerequisites Installation

### Install Tools
```bash
# Install Minikube
brew install minikube

# Install kubectl
brew install kubectl

# Install Helm
brew install helm

# Install Stern
brew install stern

# Verify installations
minikube version
kubectl version --client
helm version
stern version
```

## Cluster Setup

### Start Minikube
```bash
minikube start --profile=istio-demo --cpus=2 --memory=3072
kubectl cluster-info
```

## Istio Installation

### Add Helm Repository
```bash
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update
```

### Install Istio Components
```bash
# Install Istio Base
helm install istio-base istio/base -n istio-system --create-namespace --set defaultRevision=default --wait

# Install Gateway API CRDs
kubectl get crd gateways.gateway.networking.k8s.io &> /dev/null || kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.0.0/standard-install.yaml

# Install istiod (Control Plane)
helm install istiod istio/istiod -n istio-system --set profile=ambient --wait

# Install Istio CNI
helm install istio-cni istio/cni -n istio-system --set profile=ambient --wait

# Install ztunnel (Data Plane)
helm install ztunnel istio/ztunnel -n istio-system --wait

# Install Ingress Gateway
helm install istio-ingressgateway istio/gateway -n istio-ingress --create-namespace
```

### Install Istioctl
```bash
curl -sL https://istio.io/downloadIstioctl | sh -
export PATH=$HOME/.istioctl/bin:$PATH
```

### Verify Installation
```bash
helm list -n istio-system
kubectl get pods -n istio-system
```

## Observability Setup

### Download Addons
```bash
mkdir -p istio-addons
curl -L https://raw.githubusercontent.com/istio/istio/release-1.25/samples/addons/prometheus.yaml -o istio-addons/prometheus.yaml
curl -L https://raw.githubusercontent.com/istio/istio/release-1.25/samples/addons/grafana.yaml -o istio-addons/grafana.yaml
curl -L https://raw.githubusercontent.com/istio/istio/release-1.25/samples/addons/kiali.yaml -o istio-addons/kiali.yaml
curl -L https://raw.githubusercontent.com/istio/istio/release-1.25/samples/addons/jaeger.yaml -o istio-addons/jaeger.yaml
```

### Apply Observability Stack
```bash
kubectl apply -f istio-addons/ -n istio-system
```

### Fix Kiali Configuration (if needed)

**ADD to istio-addons/kiali.yaml:**

```yaml
external_services:
  custom_dashboards:
    enabled: true
  grafana:
    enabled: true
    in_cluster_url: 'http://grafana.istio-system:3000'
    url: 'http://grafana.istio-system:3000'
  istio:
    root_namespace: istio-system
  prometheus:
    url: 'http://prometheus.istio-system:9090'
  tracing:
    enabled: false
```

**REPLACE the existing:**

```yaml
external_services:
  custom_dashboards:
    enabled: true
  istio:
    root_namespace: istio-system
  tracing:
    enabled: false
```

**Apply the fix:**
```bash
# Apply fixed kiali.yaml
kubectl apply -f istio-addons/kiali.yaml

# Restart Kiali deployment
kubectl rollout restart deployment/kiali -n istio-system
kubectl rollout status deployment/kiali -n istio-system
```

### Verify Observability Services
```bash
kubectl get pods -n istio-system | grep -E "(kiali|prometheus|grafana|jaeger)"
kubectl get svc -n istio-system | grep -E "(kiali|prometheus|grafana|jaeger)"
```

## Bookinfo Application

### Deploy Application
```bash
# Create namespace
kubectl create namespace bookinfo

# Deploy bookinfo app
kubectl apply -f k8s/bookinfo.yaml -n bookinfo

# Verify pods
kubectl get pods -n bookinfo

# Apply gateway configuration
kubectl apply -f k8s/bookinfo-gateway.yaml -n bookinfo
```

### Add to Ambient Mesh
```bash
kubectl label namespace bookinfo istio.io/dataplane-mode=ambient
```

### Expose Application
```bash
# Check ingress gateway service
kubectl get svc istio-ingressgateway -n istio-ingress

# Start minikube tunnel (in separate terminal)
minikube tunnel -p istio-demo

# Test access
curl http://localhost/productpage
```

## Access Dashboards

### Open Dashboards
```bash
# Kiali
istioctl dashboard kiali

# Grafana
istioctl dashboard grafana

# Jaeger
istioctl dashboard jaeger

# Prometheus
istioctl dashboard prometheus
```

### Port Forward (Alternative)
```bash
# Kiali
kubectl port-forward svc/kiali -n istio-system 20001:20001

# Grafana
kubectl port-forward svc/grafana -n istio-system 3000:3000

# Prometheus
kubectl port-forward svc/prometheus -n istio-system 9090:9090

# Jaeger
kubectl port-forward svc/tracing -n istio-system 16686:80
```

## Generate Traffic

### Simulate Traffic
```bash
# Generate traffic to bookinfo
for i in $(seq 1 100); do
  curl -s http://localhost/productpage > /dev/null
  echo "Request $i sent"
  sleep 1
done
```

## Verification Commands

### Check Services
```bash
kubectl get pods -n istio-system
kubectl get svc -n istio-system
kubectl get pods -n bookinfo
kubectl get svc -n bookinfo
```

### Check Ambient Mesh
```bash
# Verify ztunnel workloads
istioctl ztunnel-config workloads

# Check mesh status
kubectl get pods -n istio-system | grep ztunnel
```

## Cleanup

### Delete Application
```bash
kubectl delete namespace bookinfo
```

### Delete Observability
```bash
kubectl delete -f istio-addons/ -n istio-system
```

### Uninstall Istio
```bash
helm uninstall ztunnel -n istio-system
helm uninstall istio-cni -n istio-system
helm uninstall istiod -n istio-system
helm uninstall istio-ingressgateway -n istio-ingress
helm uninstall istio-base -n istio-system
kubectl delete namespace istio-system
kubectl delete namespace istio-ingress
```

### Stop Minikube
```bash
minikube stop -p istio-demo
minikube delete -p istio-demo
```