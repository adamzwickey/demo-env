# bin/bash

if [ ! $# -eq 3 ]; then
  echo "Must supply Cluster Name, Harbor, and Notary FQDN as args"
  exit 1
fi
CLUSTER_NAME=$1
HARBOR=$2
NOTARY=$3

mkdir -p generated/$CLUSTER_NAME/harbor/

# 01-namespace.yaml
yq read tkg-lab/clusters/mgmt/harbor/01-namespace.yaml > generated/$CLUSTER_NAME/harbor/01-namespace.yaml

# 02-certs.yaml
yq read tkg-lab/clusters/mgmt/harbor/02-certs.yaml > generated/$CLUSTER_NAME/harbor/02-certs.yaml
yq write generated/$CLUSTER_NAME/harbor/02-certs.yaml -i "spec.commonName" $HARBOR
yq write generated/$CLUSTER_NAME/harbor/02-certs.yaml -i "spec.dnsNames[0]" $HARBOR
yq write generated/$CLUSTER_NAME/harbor/02-certs.yaml -i "spec.dnsNames[1]" $NOTARY

# harbor-values.yaml
yq read tkg-lab/clusters/mgmt/harbor/harbor-values.yaml > generated/$CLUSTER_NAME/harbor/harbor-values.yaml
yq write generated/$CLUSTER_NAME/harbor/harbor-values.yaml -i "expose.ingress.hosts.core" $HARBOR
yq write generated/$CLUSTER_NAME/harbor/harbor-values.yaml -i "expose.ingress.hosts.notary" $NOTARY 
yq write generated/$CLUSTER_NAME/harbor/harbor-values.yaml -i "externalURL" https://$HARBOR

kubectl apply -f generated/$CLUSTER_NAME/harbor/01-namespace.yaml 
kubectl apply -f generated/$CLUSTER_NAME/harbor/02-certs.yaml

#Wait for cert to be ready
while kubectl get certificates -n harbor harbor-cert | grep True ; [ $? -ne 0 ]; do
	echo Harbor certificate is not yet ready
	sleep 5s
done

helm repo add harbor https://helm.goharbor.io
helm install harbor harbor/harbor -f generated/$CLUSTER_NAME/harbor/harbor-values.yaml --namespace harbor


