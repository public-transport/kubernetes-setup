#!/bin/bash
set -e # exit on error

# see also: https://www.digitalocean.com/community/tutorials/how-to-set-up-an-elasticsearch-fluentd-and-kibana-efk-logging-stack-on-kubernetes

kubectl create namespace kube-logging

kubectl apply -f $(dirname "$0")/elasticsearch-service.yaml
kubectl apply -f $(dirname "$0")/elasticsearch-statefulset.yaml
kubectl rollout status sts/es-cluster --namespace=kube-logging

kubectl apply -f $(dirname "$0")/kibana.yaml
kubectl rollout status deployment/kibana --namespace=kube-logging

kubectl apply -f $(dirname "$0")/fluentd.yaml
kubectl get ds --namespace=kube-logging
