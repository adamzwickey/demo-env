# /bin/bash

if [ ! $# -eq 2 ]; then
  echo "Must supply cluster name and metal lb CIDR range as args"
  exit 1
fi
CLUSTER_NAME=$1
CIDR=$2

mkdir -p generated/$CLUSTER_NAME/metal-lb
cp vmw/mlb.yml generated/$CLUSTER_NAME/metal-lb
sed -i '' -e 's/CIDR/'$CIDR'/g' generated/$CLUSTER_NAME/metal-lb/mlb.yml

kubectl create ns metallb-system
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.9.2/manifests/metallb.yaml -n metallb-system
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
kubectl apply -f generated/$CLUSTER_NAME/metal-lb/mlb.yml