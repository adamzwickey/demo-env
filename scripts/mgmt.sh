#!/bin/bash -e

ENABLED=$(yq r $PARAMS_YAML management-cluster.deploy)
if [ "$ENABLED" = "true" ];
then
  echo "*********************************"
  echo "Deploying AWS Mgmt Cluster"
  echo "*********************************"
  # Management Step 1
  $TKG_LAB_SCRIPTS/01-prep-aws-objects.sh
  $TKG_LAB_SCRIPTS/02-deploy-aws-mgmt-cluster.sh
  $TKG_LAB_SCRIPTS/03-post-deploy-mgmt-cluster.sh
  # Management Step 2
  $TKG_LAB_SCRIPTS/tmc-attach.sh $(yq r $PARAMS_YAML management-cluster.name)
  # Management Step 3
  $TKG_LAB_SCRIPTS/create-hosted-zone.sh
  $TKG_LAB_SCRIPTS/retrieve-lets-encrypt-ca-cert.sh
  # Management Step 6
  $TKG_LAB_SCRIPTS/generate-and-apply-contour-yaml.sh $(yq r $PARAMS_YAML management-cluster.name)
  $TKG_LAB_SCRIPTS/update-dns-records-route53.sh $(yq r $PARAMS_YAML management-cluster.ingress-fqdn)
  $TKG_LAB_SCRIPTS/generate-and-apply-cluster-issuer-yaml.sh $(yq r $PARAMS_YAML management-cluster.name)
  # Management Step 7
  $TKG_LAB_SCRIPTS/generate-and-apply-dex-yaml.sh
  # Management Step 8
  $TKG_LAB_SCRIPTS/deploy-wavefront.sh $(yq r $PARAMS_YAML management-cluster.name)
else
  echo "mgmt cluster not enabled"
fi

