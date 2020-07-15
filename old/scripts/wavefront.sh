# bin/bash

: ${WAVEFRONT_API_KEY?"Need to set WAVEFRONT_API_KEY environment variable"}
: ${WAVEFRONT_URL?"Need to set WAVEFRONT_URL environment variable"}
: ${WAVEFRONT_PREFIX?"Need to set WAVEFRONT_PREFIX environment variable"}

if [ ! $# -eq 1 ]; then
  echo "Must supply cluster name as args"
  exit 1
fi
CLUSTER_NAME=$1

kubectl create namespace wavefront
helm repo add wavefront https://wavefronthq.github.io/helm/
helm repo update
helm install wavefront wavefront/wavefront -f tkg-lab/clusters/mgmt/wavefront/wf.yml \
  --set wavefront.url=$WAVEFRONT_URL \
  --set wavefront.token=$WAVEFRONT_API_KEY \
  --set clusterName=$WAVEFRONT_PREFIX-$CLUSTER_NAME \
  --namespace wavefront