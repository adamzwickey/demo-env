# bin/bash

: ${TMC_WORKSPACE?"Need to set TMC_WORKSPACE environment variable"}
: ${VMWARE_ID?"Need to set VMWARE_ID environment variable"}

if [ ! $# -eq 1 ]; then
 echo "Must supply cluster name as args"
 exit 1
fi
CLUSTER_NAME=$1

mkdir -p generated/$CLUSTER_NAME/tmc
cp -r tkg-lab/tmc/config/ generated/$CLUSTER_NAME/tmc/

# tkg-mgmt-acme-fitness.yaml
yq write -d0 generated/$CLUSTER_NAME/tmc/namespace/tkg-mgmt-acme-fitness.yaml -i "fullName.clusterName" $TMC_CLUSTER_GROUP-$CLUSTER_NAME
yq write -d0 generated/$CLUSTER_NAME/tmc/namespace/tkg-mgmt-acme-fitness.yaml -i "objectMeta.labels.origin" $VMWARE_ID
yq write -d0 generated/$CLUSTER_NAME/tmc/namespace/tkg-mgmt-acme-fitness.yaml -i "spec.workspaceName" $TMC_WORKSPACE

# acme-fitness-dev.yaml
yq write -d0 generated/$CLUSTER_NAME/tmc/workspace/acme-fitness-dev.yaml -i "fullName.name" $TMC_WORKSPACE
yq write -d0 generated/$CLUSTER_NAME/tmc/workspace/acme-fitness-dev.yaml -i "objectMeta.labels.origin" $VMWARE_ID

tmc workspace create -f generated/$CLUSTER_NAME/tmc/workspace/acme-fitness-dev.yaml
tmc workspace iam add-binding $TMC_WORKSPACE --role workspace.edit --groups acme-fitness-devs
#tmc cluster namespace create -f generated/$CLUSTER_NAME/tmc/namespace/tkg-mgmt-acme-fitness.yaml
tmc cluster namespace create --cluster-name $TMC_CLUSTER_GROUP-$CLUSTER_NAME \
    --name acme-fitness --workspace-name $TMC_WORKSPACE 