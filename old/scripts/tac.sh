# bin/bash

: ${TAC_REPO_URL?"Need to set TAC_REPO_URL environment variable"}

if [ ! $# -eq 1 ]; then
  echo "Must supply Catalog ingress name as args"
  exit 1
fi
INGRESS=$1

kubectl create namespace kubeapps
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install kubeapps bitnami/kubeapps --namespace kubeapps \
    -f manifests/tac/kubeapp-values.yml \
    --set ingress.hostname=$INGRESS

kubectl create serviceaccount kubeapps-operator
kubectl create clusterrolebinding kubeapps-operator --clusterrole=cluster-admin --serviceaccount=default:kubeapps-operator
kubectl get secret $(kubectl get serviceaccount kubeapps-operator -o jsonpath='{range .secrets[*]}{.name}{"\n"}{end}' | grep kubeapps-operator-token) -o jsonpath='{.data.token}' -o go-template='{{.data.token | base64decode}}' && echo

helm repo add TAC $TAC_REPO_URL
helm repo update