#!/bin/bash
set -e # exit on error

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/mandatory.yaml
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/provider/cloud-generic.yaml

# controller pods should have been created
kubectl get pods --all-namespaces -l app.kubernetes.io/name=ingress-nginx

echo "run 'kubectl get svc --namespace=ingress-nginx' to retrieve the load balancer's external IP address"
