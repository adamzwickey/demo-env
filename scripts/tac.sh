# bin/bash

: ${PARAMS_YAML?"Need to set PARAMS_YAML environment variable"}

CLUSTER_NAME=$(yq r $PARAMS_YAML workload-cluster.name)
kubectl config use-context $CLUSTER_NAME-admin@$CLUSTER_NAME

INGRESS=$(yq r $PARAMS_YAML tac.ingress-fqdn)
kubectl create namespace kubeapps
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install kubeapps bitnami/kubeapps --namespace kubeapps \
    -f tac/kubeapp-values.yml \
    --set ingress.hostname=$INGRESS

kubectl create serviceaccount kubeapps-operator
kubectl create clusterrolebinding kubeapps-operator --clusterrole=cluster-admin --serviceaccount=default:kubeapps-operator
kubectl get secret $(kubectl get serviceaccount kubeapps-operator -o jsonpath='{range .secrets[*]}{.name}{"\n"}{end}' | grep kubeapps-operator-token) -o jsonpath='{.data.token}' -o go-template='{{.data.token | base64decode}}' && echo

helm repo add TAC $TAC_REPO_URL
helm repo update