#!/bin/bash
set -e # exit on error

kubectl create namespace cert-manager

kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.14.0/cert-manager.yaml

# cert-manager pods should have been created
kubectl get pods --namespace cert-manager
