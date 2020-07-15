# bin/bash

: ${VMWARE_ID?"Need to set VMWARE_ID environment variable"}
: ${TMC_CLUSTER_GROUP?"Need to set TMC_CLUSTER_GROUP environment variable"}

if [ ! $# -eq 2 ]; then
  echo "Must supply cluster name and IAAS as args"
  exit 1
fi
CLUSTER_NAME=$1
IAAS=$2

mkdir -p generated/$CLUSTER_NAME

tmc cluster attach \
  --name $TMC_CLUSTER_GROUP-$CLUSTER_NAME \
  --labels origin=$VMWARE_ID \
  --labels iaas=$IAAS \
  --group $TMC_CLUSTER_GROUP \
  --output generated/$CLUSTER_NAME/tmc.yaml
kubectl apply -f generated/$CLUSTER_NAME/tmc.yaml
echo "$CLUSTER_NAME registered with TMC"