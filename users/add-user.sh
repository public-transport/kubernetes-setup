#!/bin/bash
set -e # exit on error

# see also: https://www.digitalocean.com/community/tutorials/recommended-steps-to-secure-a-digitalocean-kubernetes-cluster

USERNM=$1
if [ -z "$USERNM" ]; then
    echo "Please specify a user."
	exit 1
fi

# create a temporary directory for storing the key/csr files
TEMP_DIR=$(dirname "$0")/temp
mkdir -p $TEMP_DIR

# generate a key
openssl genrsa -out $TEMP_DIR/$USERNM.key 4096

# configure the certificate signing request file
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

# send and approve the certificate signing request
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

# store the user certificate in a temporary file
kubectl get csr $AUTH_NAME -o jsonpath='{.status.certificate}' | base64 --decode > $TEMP_DIR/$USERNM.crt

# prepare a namespace for the user
echo "apiVersion: v1
kind: Namespace
metadata:
  name: $USERNM
---" >> $(dirname "$0")/$USERNM.yaml

# prepare a service account for the namespace
echo "apiVersion: v1
kind: ServiceAccount
metadata:
  name: $USERNM-service-account
  namespace: $USERNM
---" >> $(dirname "$0")/$USERNM.yaml

# prepare the rolebindings for the user and service account
echo "apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: edit-$USERNM-rb
  namespace: $USERNM
subjects:
- kind: User
  name: $USERNM
  apiGroup: \"\"
- kind: ServiceAccount
  name: $USERNM
  apiGroup: \"\"
roleRef:
  kind: ClusterRole
  name: edit
  apiGroup: \"\"
---" >> $(dirname "$0")/$USERNM.yaml

echo "apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: view-logs-$USERNM-rb
  namespace: kube-logging
subjects:
- kind: User
  name: $USERNM
  apiGroup: \"\"
roleRef:
  kind: ClusterRole
  name: view
  apiGroup: \"\"" >> $(dirname "$0")/$USERNM.yaml

kubectl apply -f $(dirname "$0")/$USERNM.yaml

KEY_DATA=$(cat $TEMP_DIR/$USERNM.key | base64 | tr -d '\n')
CRT_DATA=$(cat $TEMP_DIR/$USERNM.crt | base64 | tr -d '\n')
echo "key: $KEY_DATA
certificate: $CRT_DATA" > $(dirname "$0")/$USERNM-credentials.yaml

rm -rf $TEMP_DIR
