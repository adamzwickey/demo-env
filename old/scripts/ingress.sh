# bin/bash

: ${LETS_ENCRYPT_ACME_EMAIL?"Need to set LETS_ENCRYPT_ACME_EMAIL environment variable"}
: ${GCP_DNS_BASE?"Need to set GCP_DNS_BASE environment variable"}

if [ ! $# -eq 3 ]; then
  echo "Must supply cluster name, IAAS, and DNS as args"
  exit 1
fi
CLUSTER_NAME=$1
IAAS=$2
DNS=$3

kubectl create ns tanzu-system-ingress
if [[ "$CLUSTER_NAME" == *"workload"* ]]; then
  kubectl apply -f tkg-extensions/cert-manager/
  #All 3 pods need to be running
  while kubectl get po -n cert-manager | grep Running | wc -l | grep 3 ; [ $? -ne 0 ]; do
	    echo Cert Manager is not yet ready
	    sleep 5s
  done
fi

ytt -f tkg-extensions/common/ -f tkg-extensions/ingress/contour/ -v infrastructure_provider="$IAAS" --output-directory generated/$CLUSTER_NAME/contour/$IAAS/
cp vmw/02-service-envoy.yaml generated/$CLUSTER_NAME/contour/$IAAS/
kubectl apply -f generated/$CLUSTER_NAME/contour/$IAAS/
sleep 10s #Wait a sec to get DNS/IP assigned

#AWS LB (dns record)
if [[ $IAAS = "aws" ]]; then
    #DNS
    EXTERNAL_IP=$(kubectl get svc envoy -n tanzu-system-ingress -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")
    echo "Envoy external IP: $EXTERNAL_IP"

    gcloud dns record-sets list --zone $GCP_DNS_BASE | grep "$DNS"
    dnsRecordExists=$?
    if [ $dnsRecordExists -eq 0 ]; then
        CURR_CNAME=$(gcloud dns record-sets list --zone $GCP_DNS_BASE | grep "$DNS" | awk '{print $4}') 
        gcloud dns record-sets transaction start --zone $GCP_DNS_BASE
        gcloud dns record-sets transaction remove --zone $GCP_DNS_BASE --name $DNS --type CNAME $CURR_CNAME --ttl 300
        gcloud dns record-sets transaction execute --zone $GCP_DNS_BASE
        sleep 10s
    fi
    #Now Create new record
    gcloud dns record-sets transaction start --zone $GCP_DNS_BASE
    gcloud dns record-sets transaction add --zone $GCP_DNS_BASE --name $DNS --type CNAME $EXTERNAL_IP. --ttl 300
    gcloud dns record-sets transaction execute --zone $GCP_DNS_BASE

    #Cluster Cert Issuer
    mkdir -p generated/$CLUSTER_NAME/certs
    yq read tkg-lab/tkg-extensions-mods-examples/ingress/contour/contour-cluster-issuer.yaml > generated/$CLUSTER_NAME/certs/contour-cluster-issuer.yaml
    yq write -d0 generated/$CLUSTER_NAME/certs/contour-cluster-issuer.yaml -i "spec.acme.email" $LETS_ENCRYPT_ACME_EMAIL  
    kubectl create secret generic acme-account-key \
      --from-file=tls.key=keys/acme-account-private-key.pem \
      -n tanzu-system-ingress
    kubectl apply -f generated/$CLUSTER_NAME/certs/contour-cluster-issuer.yaml
fi

#vSphere LB (IP)
if [[ $IAAS = "vsphere" ]]; then

    #DNS
    EXTERNAL_IP=$(kubectl get svc envoy -n tanzu-system-ingress -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
    echo "Envoy external IP: $EXTERNAL_IP"

    gcloud dns record-sets list --zone $GCP_DNS_BASE | grep "$DNS"
    dnsRecordExists=$?
    if [ $dnsRecordExists -eq 0 ]; then
        CURR_CNAME=$(gcloud dns record-sets list --zone $GCP_DNS_BASE | grep "$DNS" | awk '{print $4}') 
        gcloud dns record-sets transaction start --zone $GCP_DNS_BASE
        gcloud dns record-sets transaction remove --zone $GCP_DNS_BASE --name $DNS --type A $CURR_CNAME --ttl 300
        gcloud dns record-sets transaction execute --zone $GCP_DNS_BASE
        sleep 10s
    fi
    #Now Create new record
    gcloud dns record-sets transaction start --zone $GCP_DNS_BASE
    gcloud dns record-sets transaction add --zone $GCP_DNS_BASE --name $DNS --type A $EXTERNAL_IP --ttl 300
    gcloud dns record-sets transaction execute --zone $GCP_DNS_BASE

    #Cluster Cert Issuer
    mkdir -p generated/$CLUSTER_NAME/certs
    yq read vmw/contour-cluster-issuer.yaml > generated/$CLUSTER_NAME/certs/contour-cluster-issuer.yaml
    yq write -d0 generated/$CLUSTER_NAME/certs/contour-cluster-issuer.yaml -i "spec.acme.email" $LETS_ENCRYPT_ACME_EMAIL  
    kubectl create secret generic acme-account-key \
      --from-file=tls.key=keys/acme-account-private-key.pem \
      -n tanzu-system-ingress
    #TODO figure out which NS this needs to go into
    kubectl create secret generic certbot-gcp-service-account \
      --from-file=keys/certbot-gcp-service-account.json \
      -n tanzu-system-ingress
    kubectl create secret generic certbot-gcp-service-account \
      --from-file=keys/certbot-gcp-service-account.json \
      -n cert-manager
    kubectl apply -f generated/$CLUSTER_NAME/certs/contour-cluster-issuer.yaml
fi