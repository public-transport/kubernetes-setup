#!/bin/bash
set -e

kubectl apply -f $(dirname "$0")/certificate-issuer.yaml
