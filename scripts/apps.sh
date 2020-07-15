#!/bin/bash -e

: ${PARAMS_YAML?"Need to set PARAMS_YAML environment variable"}

export TKG_LAB_SCRIPTS=tkg-lab/scripts

ENABLED=$(yq r $PARAMS_YAML apps.deploy)
if [ "$ENABLED" = "true" ];
then
  echo "*********************************"
  echo "Deploying Apps to Workload Cluster"
  echo "*********************************"
  CLUSTER_NAME=$(yq r $PARAMS_YAML workload-cluster.name)
  kubectl config use-context $CLUSTER_NAME-admin@$CLUSTER_NAME

  ./$TKG_LAB_SCRIPTS/generate-and-apply-tmc-acme-fitness-yaml.sh $(yq r $PARAMS_YAML workload-cluster.name)  
  ./$TKG_LAB_SCRIPTS/apply-acme-fitness-quota.sh
  ./$TKG_LAB_SCRIPTS/generate-acme-fitness-yaml.sh $(yq r $PARAMS_YAML workload-cluster.name)
  ./scripts/deploy-acme.sh

  ./scripts/tac.sh

else
  echo "apps in workload cluster not enabled"
fi