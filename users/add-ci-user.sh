#!/bin/bash
set -e # exit on error

USERNM_OP=$1
if [ -z "$USERNM_OP" ]; then
    echo "Please specify a user."
	exit 1
fi
USERNM=$USERNM_OP"-ci"

# create a temporary directory for storing the key/csr files
TEMP_DIR=$(dirname "$0")/temp
mkdir -p $TEMP_DIR

# generate a key
openssl genrsa -out $TEMP_DIR/$USERNM.key 4096

# configure the certificate signing request
openssl req -new -newkey rsa:4096 -nodes -keyout $TEMP_DIR/$USERNM.key -out $TEMP_DIR/$USERNM.csr -subj "/CN=$USERNM/O=known-developers-ci"

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

sleep 5;

# store the user certificate in a temporary file
USER_CRT=$(kubectl get csr $AUTH_NAME -o jsonpath='{.status.certificate}')

# create a namespace for the user (if it doesn't exist yet)
kubectl create namespace $USERNM_OP --dry-run -o yaml | kubectl apply -f -

# create a ci role for the user's namespace
echo "apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: $USERNM_OP
  name: $USERNM-role
rules:
- apiGroups: [\"\"]
  resources: [\"services\", \"deployments\", \"ingresses\", \"networking.k8s.io\"]
  verbs: [\"create\", \"update\", \"patch\", \"list\", \"get\", \"watch\"]
---" > $TEMP_DIR/$USERNM-role.yaml
kubectl apply -f $TEMP_DIR/$USERNM-role.yaml
cat $TEMP_DIR/$USERNM-role.yaml >> $(dirname "$0")/$USERNM_OP.yaml

# create the rolebinding
echo "apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $USERNM-rb
  namespace: $USERNM_OP
subjects:
- kind: User
  name: $USERNM
  apiGroup: \"\"
roleRef:
  kind: Role
  name: $USERNM-role
  apiGroup: \"\"
---" > $TEMP_DIR/$USERNM-rb.yaml
kubectl apply -f $TEMP_DIR/$USERNM-rb.yaml
cat $TEMP_DIR/$USERNM-rb.yaml >> $(dirname "$0")/$USERNM_OP.yaml

# read certificate authority from the local kubeconfig
K8S_CONTEXT=$(kubectl config view --minify -o jsonpath='{.current-context}' --raw)
K8S_CLUSTER=$(kubectl config view --minify -o jsonpath='{.contexts[?(@.name == "'$K8S_CONTEXT'")].context.cluster}' --raw)
CA_DATA=$(kubectl config view --minify -o jsonpath='{.clusters[?(@.name == "'$K8S_CLUSTER'")].cluster.certificate-authority-data}' --raw)
SERVER_DATA=$(kubectl config view --minify -o jsonpath='{.clusters[?(@.name == "'$K8S_CLUSTER'")].cluster.server}' --raw)

KEY_DATA=$(cat $TEMP_DIR/$USERNM.key | base64 | tr -d '\n')

sed -e "s|<USER>|$USERNM|" -e "s|<KEY>|$KEY_DATA|" -e "s|<CERTIFICATE>|$USER_CRT|" -e "s|<CA>|$CA_DATA|" -e "s|<SERVER>|$SERVER_DATA|" $(dirname "$0")/kubeconfig-template.yaml > $(dirname "$0")/.kubeconfig-$USERNM.yaml

rm -rf $TEMP_DIR
