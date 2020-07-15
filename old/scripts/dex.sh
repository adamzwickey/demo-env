# bin/bash

: ${OKTA_AUTH_SERVER_CN?"Need to set OCTA_AUTH_SERVER_CN environment variable"}
: ${OKTA_CLIENT_ID?"Need to set OCTA_CLIENT_ID environment variable"}
: ${OKTA_CLIENT_SECRET?"Need to set OKTA_CLIENT_SECRET environment variable"}

if [ ! $# -eq 2 ]; then
  echo "Must supply Cluster Name, Dex CN as args"
  exit 1
fi
CLUSTER_NAME=$1
DEX_CN=$2

mkdir -p generated/$CLUSTER_NAME/dex/
yq read tkg-extensions/authentication/dex/aws/oidc/02-service.yaml > generated/$CLUSTER_NAME/dex/02-service.yaml
yq read tkg-lab/tkg-extensions-mods-examples/authentication/dex/aws/oidc/02b-ingress.yaml > generated/$CLUSTER_NAME/dex/02b-ingress.yaml
yq read tkg-lab/tkg-extensions-mods-examples/authentication/dex/aws/oidc/03-certs.yaml > generated/$CLUSTER_NAME/dex/03-certs.yaml
yq read tkg-lab/tkg-extensions-mods-examples/authentication/dex/aws/oidc/04-cm.yaml > generated/$CLUSTER_NAME/dex/04-cm.yaml

# 02-service.yaml
yq write -d0 generated/$CLUSTER_NAME/dex/02-service.yaml -i "spec.type" "ClusterIP"

# 02b-ingress.yaml
yq write -d0 generated/$CLUSTER_NAME/dex/02b-ingress.yaml -i "spec.virtualhost.fqdn" $DEX_CN

# 03-certs.yaml
yq write -d0 generated/$CLUSTER_NAME/dex/03-certs.yaml -i "spec.commonName" $DEX_CN
yq write -d0 generated/$CLUSTER_NAME/dex/03-certs.yaml -i "spec.dnsNames[0]" $DEX_CN

# 04-cm.yaml
sed -i '' -e 's/$DEX_CN/'$DEX_CN'/g' generated/$CLUSTER_NAME/dex/04-cm.yaml
sed -i '' -e 's/$OCTA_AUTH_SERVER_CN/'$OKTA_AUTH_SERVER_CN'/g' generated/$CLUSTER_NAME/dex/04-cm.yaml
sed -i '' -e 's/$OCTA_DEX_APP_CLIENT_ID/'$OKTA_CLIENT_ID'/g' generated/$CLUSTER_NAME/dex/04-cm.yaml
sed -i '' -e 's/$OCTA_DEX_APP_CLIENT_SECRET/'$OKTA_CLIENT_SECRET'/g' generated/$CLUSTER_NAME/dex/04-cm.yaml

kubectl apply -f tkg-extensions/authentication/dex/aws/oidc/01-namespace.yaml
kubectl apply -f generated/$CLUSTER_NAME/dex/02-service.yaml
kubectl apply -f generated/$CLUSTER_NAME/dex/02b-ingress.yaml
kubectl apply -f generated/$CLUSTER_NAME/dex/03-certs.yaml
kubectl apply -f generated/$CLUSTER_NAME/dex/04-cm.yaml
kubectl apply -f tkg-extensions/authentication/dex/aws/oidc/05-rbac.yaml

# Same environment variables set previously
kubectl create secret generic oidc \
   --from-literal=clientId=$(echo -n $OKTA_CLIENT_ID | base64) \
   --from-literal=clientSecret=$(echo -n $OKTA_CLIENT_SECRET | base64) \
   -n tanzu-system-auth


#Wait for cert to be ready
while kubectl get certificates -n tanzu-system-auth dex-cert | grep True ; [ $? -ne 0 ]; do
	echo Dex certificate is not yet ready
	sleep 5s
done   

kubectl apply -f tkg-extensions/authentication/dex/aws/oidc/06-deployment.yaml