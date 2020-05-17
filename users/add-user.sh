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

# configure the certificate signing request
openssl req -new -newkey rsa:4096 -nodes -keyout $TEMP_DIR/$USERNM.key -out $TEMP_DIR/$USERNM.csr -subj "/CN=$USERNM/O=known-developers"

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
  - client auth
"
echo "$CSR_K8S" | kubectl apply -f -
kubectl certificate approve $AUTH_NAME

# store the user certificate in a temporary file
USER_CRT=$(kubectl get csr $AUTH_NAME -o jsonpath='{.status.certificate}')

# create a namespace for the user (if it doesn't exist yet)
kubectl create namespace $USERNM --dry-run -o yaml | kubectl apply -f -

# create a service account for the namespace
echo "apiVersion: v1
kind: ServiceAccount
metadata:
  name: $USERNM-service-account
  namespace: $USERNM
---" > $TEMP_DIR/$USERNM-service-account.yaml
kubectl apply -f $TEMP_DIR/$USERNM-service-account.yaml
cat $TEMP_DIR/$USERNM-service-account.yaml >> $(dirname "$0")/$USERNM.yaml

# create the rolebindings for the user and service account
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
---" > $TEMP_DIR/edit-$USERNM-rb.yaml
kubectl apply -f $TEMP_DIR/edit-$USERNM-rb.yaml
cat $TEMP_DIR/edit-$USERNM-rb.yaml >> $(dirname "$0")/$USERNM.yaml

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
  apiGroup: \"\"
---" > $TEMP_DIR/view-logs-$USERNM-rb.yaml
kubectl apply -f $TEMP_DIR/view-logs-$USERNM-rb.yaml
cat $TEMP_DIR/view-logs-$USERNM-rb.yaml >> $(dirname "$0")/$USERNM.yaml

echo "apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: port-forward-logs-$USERNM-rb
  namespace: kube-logging
subjects:
- kind: User
  name: $USERNM
  apiGroup: \"\"
roleRef:
  kind: Role
  name: log-port-forward
  apiGroup: \"\"
---" > $TEMP_DIR/view-logs-$USERNM-rb.yaml
kubectl apply -f $TEMP_DIR/view-logs-$USERNM-rb.yaml
cat $TEMP_DIR/view-logs-$USERNM-rb.yaml >> $(dirname "$0")/$USERNM.yaml

# read certificate authority from the local kubeconfig
K8S_CONTEXT=$(kubectl config view --minify -o jsonpath='{.current-context}' --raw)
K8S_CLUSTER=$(kubectl config view --minify -o jsonpath='{.contexts[?(@.name == "'$K8S_CONTEXT'")].context.cluster}' --raw)
CA_DATA=$(kubectl config view --minify -o jsonpath='{.clusters[?(@.name == "'$K8S_CLUSTER'")].cluster.certificate-authority-data}' --raw)
SERVER_DATA=$(kubectl config view --minify -o jsonpath='{.clusters[?(@.name == "'$K8S_CLUSTER'")].cluster.server}' --raw)

KEY_DATA=$(cat $TEMP_DIR/$USERNM.key | base64 | tr -d '\n')

sed -e "s|<USER>|$USERNM|" -e "s|<KEY>|$KEY_DATA|" -e "s|<CERTIFICATE>|$USER_CRT|" -e "s|<CA>|$CA_DATA|" -e "s|<SERVER>|$SERVER_DATA|" $(dirname "$0")/kubeconfig-template.yaml > $(dirname "$0")/.kubeconfig-$USERNM.yaml

rm -rf $TEMP_DIR
