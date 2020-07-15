# bin/bash

if [ ! $# -eq 2 ]; then
  echo "Must supply Cluster Name and Elastic Search FQDN as args"
  exit 1
fi
CLUSTER_NAME=$1
ELASTIC=$2

# Command specifies necessary overrides with -v
ytt -f tkg-extensions/common -f tkg-extensions/logging/fluent-bit/ -v infrastructure_provider="aws" \
    -v tkg.cluster_name="$CLUSTER_NAME" \
    -v tkg.instance_name="$CLUSTER_NAME" \
    -v fluent_bit.output_plugin="elasticsearch" \
    -v fluent_bit.elasticsearch.host="$ELASTIC" \
    -v fluent_bit.elasticsearch.port="80" \
    --output-directory generated/$CLUSTER_NAME/es/

kubectl apply -f generated/$CLUSTER_NAME/es/