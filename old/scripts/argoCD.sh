# bin/bash

if [ ! $# -eq 2 ]; then
  echo "Must supply cluster name and Argo ingress CN as args"
  exit 1
fi
CLUSTER_NAME=$1
INGRESS=$2

mkdir -p generated/$CLUSTER_NAME/argocd/

yq read manifests/argocd/values.yml > generated/$CLUSTER_NAME/argocd/values.yml
yq write generated/$CLUSTER_NAME/argocd/values.yml -i "server.ingress.hosts[0]" $INGRESS
yq write generated/$CLUSTER_NAME/argocd/values.yml -i "server.ingress.tls[0].hosts[0]" $INGRESS

kubectl create ns argocd
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd \
    -f generated/$CLUSTER_NAME/argocd/values.yml --namespace argocd

kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o name | cut -d'/' -f 2