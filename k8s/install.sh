#!/bin/bash

set -x

# Install Istio components
helm install istio-base istio/base -n istio-system --create-namespace --set defaultRevision=default --wait
helm install istiod istio/istiod --namespace istio-system --set profile=ambient --wait
helm install istio-cni istio/cni -n istio-system --set profile=ambient --wait
helm install ztunnel istio/ztunnel -n istio-system --wait
helm install istio-ingressgateway istio/gateway -n istio-ingress --create-namespace --wait

# Wait for Istio components to be up and running
echo "Waiting for Istio components to be deployed..."
kubectl wait --for=condition=available --timeout=600s deployment -n istio-system --all

# Check if Istio is installed correctly
helm ls -n istio-system
kubectl get pods -n istio-system

# Apply Bookinfo application
kubectl create ns bookinfo
kubectl apply -f bookinfo-gateway.yaml -n bookinfo
kubectl apply -f bookinfo.yaml -n bookinfo

# Wait for the Bookinfo workload to be up and running
echo "Waiting for Bookinfo workload to be deployed..."
kubectl wait --for=condition=available --timeout=600s deployment -n bookinfo --all

# Add bookinfo namespace to ambient mesh
echo "Adding bookinfo namespace to ambient mesh..."
kubectl label namespace bookinfo istio.io/dataplane-mode=ambient

# Apply waypoint proxy for L7 features
echo "Applying waypoint proxy..."
kubectl apply -f waypoint.yaml -n bookinfo

# Wait for waypoint to be ready
kubectl wait --for=condition=Programmed gateway/waypoint -n bookinfo --timeout=60s

# Annotate reviews service to use waypoint (critical for L7 routing)
echo "Configuring reviews service to use waypoint..."
kubectl annotate service reviews -n bookinfo istio.io/use-waypoint=waypoint

# Apply destination rules
echo "Applying destination rules..."
kubectl apply -f destination-rule.yaml -n bookinfo

# Apply default virtual service (all traffic to v1)
echo "Applying default virtual service..."
kubectl apply -f virtual-service-all-v1.yaml -n bookinfo

# Apply observability stack
echo "Applying observability components..."
kubectl apply -f ../istio-addons/ -n istio-system

# Apply PeerAuthentication for strict mTLS
kubectl apply -f PeerAuthentication.yaml -n bookinfo

echo "Istio installation and Bookinfo application completed successfully!"
echo "Access the application at: http://localhost/productpage"
echo "Open dashboards with:"
echo "  - Kiali: istioctl dashboard kiali"
echo "  - Grafana: istioctl dashboard grafana"
echo "  - Jaeger: istioctl dashboard jaeger"