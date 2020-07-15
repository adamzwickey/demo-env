#!/bin/bash -e

: ${PARAMS_YAML?"Need to set PARAMS_YAML environment variable"}

export TKG_LAB_SCRIPTS=tkg-lab/scripts

ENABLED=$(yq r $PARAMS_YAML harbor.deploy)
if [ "$ENABLED" = "true" ];
then
  echo "*********************************"
  echo "Deploying Harbor to Shared Services Cluster"
  echo "*********************************"
  CLUSTER_NAME=$(yq r $PARAMS_YAML shared-services-cluster.name)
  kubectl config use-context $CLUSTER_NAME-admin@$CLUSTER_NAME

  ./harbor/00-generate_yaml.sh $(yq r $PARAMS_YAML shared-services-cluster.name)

  kubectl apply -f generated/$CLUSTER_NAME/harbor/01-namespace.yaml
  kubectl apply -f generated/$CLUSTER_NAME/harbor/02-certs.yaml  
  
  #Wait for cert to be ready
  while kubectl get certificates -n harbor | grep True ; [ $? -ne 0 ]; do
	echo Harbor certificate is not yet ready
	sleep 5s
  done   

  helm repo add harbor https://helm.goharbor.io
  helm upgrade --install harbor harbor/harbor \
    -f generated/$CLUSTER_NAME/harbor/harbor-values.yaml \
    --namespace harbor

else
  echo "harbor in services cluster not enabled"
fi