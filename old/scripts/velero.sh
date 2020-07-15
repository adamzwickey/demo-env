#!/bin/bash -e

echo "Beginning Velero install..."

: ${VELERO_BUCKET?"Need to set VELERO_BUCKET environment variable"}
: ${VELERO_REGION?"Need to set VELERO_REGION environment variable"}

if [ ! $# -eq 1 ]; then
  echo "Must supply cluster name as arg"
  exit 1
fi
CLUSTER_NAME=$1

echo $CLUSTER_NAME | grep workload
exists=$?
if [ $exists -eq 1 ]; then
    kubectl delete clusterrolebinding cert-manager-leaderelection
else
    echo "cert-manager-leaderelection doesn't exist in workload cluster yet"
fi
echo next
velero install \
    --provider aws \
    --plugins velero/velero-plugin-for-aws:v1.0.1 \
    --bucket $VELERO_BUCKET \
    --backup-location-config region=$VELERO_REGION \
    --snapshot-location-config region=$VELERO_REGION \
    --secret-file keys/credentials-velero

#Wait for it to be ready
while kubectl get po -n velero | grep Running ; [ $? -ne 0 ]; do
	echo Velero is not yet ready
	sleep 5s
done

velero schedule create daily-$CLUSTER_NAME-cluster-backup --schedule "0 7 * * *"
velero backup get
velero schedule get