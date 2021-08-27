#!/bin/bash
set -e # exit on error

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.0.0/deploy/static/provider/scw/deploy.yaml

# controller pods should have been created
kubectl get pods --all-namespaces -l app.kubernetes.io/name=ingress-nginx

echo "run 'kubectl get svc --namespace=ingress-nginx' to retrieve the load balancer's external IP address"
