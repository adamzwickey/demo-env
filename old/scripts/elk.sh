# bin/bash

if [ ! $# -eq 3 ]; then
  echo "Must supply Cluster Name, Elastic Search and Kibana FQDNs as args"
  exit 1
fi
CLUSTER_NAME=$1
ELASTIC=$2
KIBANA=$3

mkdir -p generated/$CLUSTER_NAME/elk/
cp tkg-lab/clusters/mgmt/elasticsearch-kibana/*.yaml generated/$CLUSTER_NAME/elk/
cp tkg-lab/clusters/mgmt/elasticsearch-kibana/generated/*.yaml generated/$CLUSTER_NAME/elk/

yq write -d0 generated/$CLUSTER_NAME/elk/03b-ingress.yaml -i "spec.rules[0].host" $ELASTIC
yq write -d2 generated/$CLUSTER_NAME/elk/04-kibana.yaml -i "spec.rules[0].host" $KIBANA

kubectl apply -f generated/$CLUSTER_NAME/elk/