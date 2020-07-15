# bin/bash

#: ${GANGWAY_CN?"Need to set GANGWAY_CN environment variable"}
#: ${DEX_CN?"Need to set DEX_CN environment variable"}

if [ ! $# -eq 3 ]; then
  echo "Must supply Cluster Name, Dex CN, and GangwayCN  as args"
  exit 1
fi
CLUSTER_NAME=$1
DEX_CN=$2
GANGWAY_CN=$3

mkdir -p generated/$CLUSTER_NAME/gangway/

# 02-service.yaml
yq read tkg-extensions/authentication/gangway/aws/02-service.yaml > generated/$CLUSTER_NAME/gangway/02-service.yaml
yq write -d0 generated/$CLUSTER_NAME/gangway/02-service.yaml -i "spec.type" "ClusterIP"

# 02b-ingress.yaml
yq read tkg-lab/tkg-extensions-mods-examples/authentication/gangway/aws/02b-ingress.yaml > generated/$CLUSTER_NAME/gangway/02b-ingress.yaml
yq write -d0 generated/$CLUSTER_NAME/gangway/02b-ingress.yaml -i "spec.virtualhost.fqdn" $GANGWAY_CN

# 03-config.yaml
yq read tkg-lab/tkg-extensions-mods-examples/authentication/gangway/aws/03-config.yaml > generated/$CLUSTER_NAME/gangway/03-config.yaml
sed -i '' -e 's/$DEX_CN/'$DEX_CN'/g' generated/$CLUSTER_NAME/gangway/03-config.yaml
sed -i '' -e 's/$GANGWAY_CN/'$GANGWAY_CN'/g' generated/$CLUSTER_NAME/gangway/03-config.yaml
sed -i '' -e 's/wlc-1/'$CLUSTER_NAME'/g' generated/$CLUSTER_NAME/gangway/03-config.yaml

API_SERVER_URL=`kubectl config view -o jsonpath="{.clusters[?(@.name=='$CLUSTER_NAME')].cluster.server}"`
API_SERVER_CN=`echo $API_SERVER_URL | cut -d ':' -f 2 | cut -d '/' -f 3 `
sed -i '' -e 's/WLC_1_API_SERVER_CN/'$API_SERVER_CN'/g' generated/$CLUSTER_NAME/gangway/03-config.yaml

# 05-certs.yaml
yq read tkg-lab/tkg-extensions-mods-examples/authentication/gangway/aws/05-certs.yaml > generated/$CLUSTER_NAME/gangway/05-certs.yaml
yq write -d0 generated/$CLUSTER_NAME/gangway/05-certs.yaml -i "spec.commonName" $GANGWAY_CN
yq write -d0 generated/$CLUSTER_NAME/gangway/05-certs.yaml -i "spec.dnsNames[0]" $GANGWAY_CN

kubectl apply -f tkg-extensions/authentication/gangway/aws/01-namespace.yaml
kubectl apply -f generated/$CLUSTER_NAME/gangway/02-service.yaml
kubectl apply -f generated/$CLUSTER_NAME/gangway/02b-ingress.yaml
kubectl apply -f generated/$CLUSTER_NAME/gangway/03-config.yaml
# Below is FOO_SECRET intentionally hard coded
kubectl create secret generic gangway \
   --from-literal=sessionKey=$(openssl rand -base64 32) \
   --from-literal=clientSecret=FOO_SECRET \
   -n tanzu-system-auth
kubectl apply -f generated/$CLUSTER_NAME/gangway/05-certs.yaml

while kubectl get certificate gangway-cert -n tanzu-system-auth | grep True ; [ $? -ne 0 ]; do
	echo Gangway cert is not yet ready
	sleep 5s
done
kubectl create cm dex-ca -n tanzu-system-auth --from-file=dex-ca.crt=keys/letsencrypt-ca.pem
kubectl apply -f tkg-extensions/authentication/gangway/aws/06-deployment.yaml