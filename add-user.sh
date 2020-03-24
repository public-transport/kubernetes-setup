#!/bin/bash
set -e # exit on error

# see also: https://www.digitalocean.com/community/tutorials/recommended-steps-to-secure-a-digitalocean-kubernetes-cluster

USERNM=$1
if [ -z "$USERNM" ]; then
    echo "Please specify a user."
	exit 1
fi

NAMESPACE=$2
if [ -z "$NAMESPACE" ]; then
    echo "Please specify a namespace."
	exit 1
fi

TEMP_DIR=$(dirname "$0")/temp
mkdir -p $TEMP_DIR

openssl genrsa -out $TEMP_DIR/$USERNM.key 4096

CSR_CNF="[ req ]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
[ dn ]
CN = $USERNM
O = known-developers
[ v3_ext ]
authorityKeyIdentifier=keyid,issuer:always
basicConstraints=CA:FALSE
keyUsage=keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth,clientAuth
"
echo "$CSR_CNF" > $TEMP_DIR/$USERNM.csr.cnf

openssl req -config $TEMP_DIR/$USERNM.csr.cnf -new -key $TEMP_DIR/$USERNM.key -nodes -out $TEMP_DIR/$USERNM.csr

AUTH_NAME="$USERNM-authentication"
CSR_K8S="apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: $AUTH_NAME
spec:
  groups:
  - system:authenticated
  request: $(cat $TEMP_DIR/$USERNM.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
  - client auth
"
echo "$CSR_K8S" | kubectl apply -f -

kubectl certificate approve $AUTH_NAME
kubectl get csr $AUTH_NAME -o jsonpath='{.status.certificate}' | base64 --decode > $TEMP_DIR/$USERNM.crt

ROLE_NAME="$USERNM-edit-role"
kubectl create rolebinding $ROLE_NAME --clusterrole=edit --user=$USERNM --namespace=$NAMESPACE

echo "
---------------------------------------------------------------
"

KEY_DATA=$(cat $TEMP_DIR/$USERNM.key | base64 | tr -d '\n')
echo "key:
$KEY_DATA

"

CRT_DATA=$(cat $TEMP_DIR/$USERNM.crt | base64 | tr -d '\n')
echo "certificate:
$CRT_DATA

"

rm -rf $TEMP_DIR
