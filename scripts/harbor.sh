#!/bin/bash -e

: ${PARAMS_YAML?"Need to set PARAMS_YAML environment variable"}

export TKG_LAB_SCRIPTS=tkg-lab/scripts

ENABLED=$(yq r $PARAMS_YAML harbor.deploy)
if [ "$ENABLED" = "true" ];
then
  echo "*********************************"
  echo "Deploying Harbor to Shared Services Cluster"
  echo "*********************************"
  

else
  echo "shared services cluster not enabled"
fi