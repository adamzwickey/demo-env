#!/bin/bash -e

ENABLED=$(yq r $PARAMS_YAML shared-services-cluster.deploy)
if [ "$ENABLED" = "true" ];
then
  echo "*********************************"
  echo "Deploying AWS Shared Services Cluster"
  echo "*********************************"
  # # Shared Services Step 1
  # $TKG_LAB_SCRIPTS/deploy-workload-cluster.sh \
  #   $(yq r $PARAMS_YAML shared-services-cluster.name) \
  #   $(yq r $PARAMS_YAML shared-services-cluster.worker-replicas)
  # # Shared Services Step 2
  # $TKG_LAB_SCRIPTS/tmc-attach.sh $(yq r $PARAMS_YAML shared-services-cluster.name)
  # # Shared Services Step 3
  # $TKG_LAB_SCRIPTS/tmc-policy.sh \
  #   $(yq r $PARAMS_YAML shared-services-cluster.name) \
  #   cluster.admin \
  #   platform-team
  # # Shared Services Step 4
  # $TKG_LAB_SCRIPTS/deploy-cert-manager.sh
  # $TKG_LAB_SCRIPTS/generate-and-apply-contour-yaml.sh $(yq r $PARAMS_YAML shared-services-cluster.name)
  # $TKG_LAB_SCRIPTS/update-dns-records-route53.sh $(yq r $PARAMS_YAML shared-services-cluster.ingress-fqdn)
  # $TKG_LAB_SCRIPTS/generate-and-apply-cluster-issuer-yaml.sh $(yq r $PARAMS_YAML shared-services-cluster.name)
  # # Shared Services Step 5
  # $TKG_LAB_SCRIPTS/generate-and-apply-gangway-yaml.sh \
  #    $(yq r $PARAMS_YAML shared-services-cluster.name) \
  #    $(yq r $PARAMS_YAML shared-services-cluster.gangway-fqdn)
  # $TKG_LAB_SCRIPTS/inject-dex-client.sh \
  #    $(yq r $PARAMS_YAML management-cluster.name) \
  #    $(yq r $PARAMS_YAML shared-services-cluster.name) \
  #    $(yq r $PARAMS_YAML shared-services-cluster.gangway-fqdn)
  # # Shared Services Step 6
  # $TKG_LAB_SCRIPTS/generate-and-apply-elasticsearch-kibana-yaml.sh
  # # Shared Services Step 7
  # $TKG_LAB_SCRIPTS/generate-and-apply-fluent-bit-yaml.sh $(yq r $PARAMS_YAML shared-services-cluster.name)
  # # Shared Services Step 8
  # $TKG_LAB_SCRIPTS/deploy-wavefront.sh $(yq r $PARAMS_YAML shared-services-cluster.name)
  # Shared Services Step 9
  #$TKG_LAB_SCRIPTS/velero.sh $(yq r $PARAMS_YAML shared-services-cluster.name)

  # Harbor
  ./scripts/harbor.sh

  # Link management to new shared services cluster
  # Management Step 9
  $TKG_LAB_SCRIPTS/generate-and-apply-fluent-bit-yaml.sh $(yq r $PARAMS_YAML management-cluster.name)
  # Management Step 10
  #$TKG_LAB_SCRIPTS/velero.sh $(yq r $PARAMS_YAML management-cluster.name)

else
  echo "shared services cluster not enabled"
fi