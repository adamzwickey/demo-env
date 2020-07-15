# /bin/bash

if [ ! $# -eq 3 ]; then
  echo "Must supply cluster name and deploy/generate and acme fitness CN as args"
  exit 1
fi
CLUSTER_NAME=$1
DEPLOY=$2
ACME_CN=$3

mkdir -p generated/$CLUSTER_NAME/acme-fitness
cp manifests/acme-fitness/acme-fitness-frontend-ingress.yaml generated/$CLUSTER_NAME/acme-fitness/
cp acme_fitness_demo/kubernetes-manifests/secrets.yaml generated/$CLUSTER_NAME/acme-fitness/
cp acme_fitness_demo/kubernetes-manifests/acme_fitness* generated/$CLUSTER_NAME/acme-fitness/

yq write -d0 generated/$CLUSTER_NAME/acme-fitness/acme-fitness-frontend-ingress.yaml -i "spec.tls[0].hosts[0]" $ACME_CN
yq write -d0 generated/$CLUSTER_NAME/acme-fitness/acme-fitness-frontend-ingress.yaml -i "spec.rules[0].host" $ACME_CN

if [[ $DEPLOY = "deploy" ]]; then
    kubectl create ns acme-fitness
    kubectl apply -f generated/$CLUSTER_NAME/acme-fitness/secrets.yaml --namespace acme-fitness
    kubectl apply -f generated/$CLUSTER_NAME/acme-fitness/acme_fitness.yaml --namespace acme-fitness
    kubectl apply -f generated/$CLUSTER_NAME/acme-fitness/acme-fitness-frontend-ingress.yaml --namespace acme-fitness
fi