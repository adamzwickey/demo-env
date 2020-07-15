#!/bin/bash -e

ENABLED=$(yq r $PARAMS_YAML workload-cluster.deploy)
if [ "$ENABLED" = "true" ];
then
  echo "*********************************"
  echo "Deploying AWS Workload Cluster"
  echo "*********************************"

else
  echo "workload cluster not enabled"
fi