#!/bin/bash -e

ENABLED=$(yq r $PARAMS_YAML workload-cluster.deploy)
if [ "$ENABLED" = "true" ];
then
  echo "*********************************"
  echo "Deploying AWS Workload Cluster"
  echo "*********************************"
  # Workload Step 1
  $TKG_LAB_SCRIPTS/deploy-workload-cluster.sh \
    $(yq r $PARAMS_YAML workload-cluster.name) \
    $(yq r $PARAMS_YAML workload-cluster.worker-replicas)
  # Workload Step 2
  $TKG_LAB_SCRIPTS/tmc-attach.sh $(yq r $PARAMS_YAML workload-cluster.name)
  # Workload Step 3
  $TKG_LAB_SCRIPTS/tmc-policy.sh \
    $(yq r $PARAMS_YAML workload-cluster.name) \
    cluster.admin \
    platform-team
  # Workload Step 4
  IAAS=$(yq r $PARAMS_YAML iaas)
  if [ "$IAAS" = "vsphere" ];
  then
    $TKG_LAB_SCRIPTS/deploy-metallb.sh \
            $(yq r $PARAMS_YAML workload-cluster.name) \
            $(yq r $PARAMS_YAML workload-cluster.metallb-start-ip) \
            $(yq r $PARAMS_YAML workload-cluster.metallb-end-ip)
  fi
  $TKG_LAB_SCRIPTS/deploy-cert-manager.sh
  $TKG_LAB_SCRIPTS/generate-and-apply-contour-yaml.sh $(yq r $PARAMS_YAML workload-cluster.name)
  $TKG_LAB_SCRIPTS/update-dns-records-route53.sh $(yq r $PARAMS_YAML workload-cluster.ingress-fqdn)
  $TKG_LAB_SCRIPTS/generate-and-apply-cluster-issuer-yaml.sh $(yq r $PARAMS_YAML workload-cluster.name)
  # Workload Step 5
  $TKG_LAB_SCRIPTS/generate-and-apply-gangway-yaml.sh \
     $(yq r $PARAMS_YAML workload-cluster.name) \
     $(yq r $PARAMS_YAML workload-cluster.gangway-fqdn)
  $TKG_LAB_SCRIPTS/inject-dex-client.sh \
     $(yq r $PARAMS_YAML management-cluster.name) \
     $(yq r $PARAMS_YAML workload-cluster.name) \
     $(yq r $PARAMS_YAML workload-cluster.gangway-fqdn)
  # Workload Step 6
  $TKG_LAB_SCRIPTS/generate-and-apply-fluent-bit-yaml.sh $(yq r $PARAMS_YAML workload-cluster.name)
  # Workload Step 7
  $TKG_LAB_SCRIPTS/deploy-wavefront.sh $(yq r $PARAMS_YAML workload-cluster.name)
  # Workload Step 8
  #$TKG_LAB_SCRIPTS/velero.sh $(yq r $PARAMS_YAML workload-cluster.name)

else
  echo "workload cluster not enabled"
fi