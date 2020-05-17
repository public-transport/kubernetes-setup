#!/bin/bash
set -e # exit on error

kubectl apply -f $(dirname "$0")/log-port-forward-rule.yaml
