# bin/bash

source keys/env.sh

#Required regardless of what we do
curl https://letsencrypt.org/certs/lets-encrypt-x3-cross-signed.pem.txt -o keys/letsencrypt-ca.pem
chmod 600 keys/letsencrypt-ca.pem

if [[ $AWS_EAST = "true" ]]; then
    echo "*********************************"
    echo "Deploying AWS EAST env..."
    echo "*********************************"

    export AWS_REGION=us-east-2
    export AWS_AMI_ID=$AWS_EAST_AMI_ID
    export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm alpha bootstrap encode-aws-credentials)

    echo $AWS_EAST_STEPS | grep mgmt-deploy
    testVal=$?
    if [ $testVal -eq 0 ]; then
        #Prep objects
        mkdir -p keys/
        if [[ ! -f ./keys/aws-east-ssh.pem ]]; then
            aws ec2 delete-key-pair --key-name tkg-east-default
            aws ec2 create-key-pair --key-name tkg-east-default --output json | jq .KeyMaterial -r > keys/aws-east-ssh.pem
        fi

        yq write ~/.tkg/config.yaml -i "AWS_NODE_AZ" $AWS_EAST_NODE_AZ
        yq write ~/.tkg/config.yaml -i "AWS_SSH_KEY_NAME" tkg-east-default
        yq write ~/.tkg/config.yaml -i "NODE_MACHINE_TYPE" $AWS_MGMT_NODE_TYPE

        tkg init --infrastructure=aws --name=$AWS_EAST_MGMT_NAME --plan=dev -v 6
        retVal=$?
        if [ $retVal -ne 0 ]; then
          return;
        fi
        tkg scale cluster $AWS_EAST_MGMT_NAME --namespace tkg-system -w $AWS_EAST_WORKER
        kubectl apply -f tkg-lab/clusters/mgmt/default-storage-class-aws.yaml
        tkg get management-clusters
        kubectl get pods -A
        kubectl get sc
    else
        echo "\nmgmt-deploy not enabled"
    fi

    #Make sure we're targeted to right cluster
    kubectx $AWS_EAST_MGMT_NAME-admin@$AWS_EAST_MGMT_NAME

    #Velero
    echo $AWS_EAST_STEPS | grep mgmt-velero
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/velero.sh $AWS_EAST_MGMT_NAME
    else
        echo "\nmgmt-velero not enabled"
    fi

    #TMC
    echo $AWS_EAST_STEPS | grep mgmt-tmc
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/tmc.sh $AWS_EAST_MGMT_NAME aws
    else
        echo "\nmgmt-tmc not enabled"
    fi

    #Ingress
    echo $AWS_EAST_STEPS | grep mgmt-ingress
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/ingress.sh $AWS_EAST_MGMT_NAME aws $AWS_EAST_MGMT_INGRESS
    else
        echo "\nmgmt-ingress not enabled"
    fi

    #Dex
    echo $AWS_EAST_STEPS | grep mgmt-dex
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/dex.sh $AWS_EAST_MGMT_NAME $AWS_EAST_MGMT_DEX_CN
    else
        echo "\nmgmt-dex not enabled"
    fi

    #Observability
    echo $AWS_EAST_STEPS | grep mgmt-observabiity
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/wavefront.sh $AWS_EAST_MGMT_NAME
    else
        echo "\nmgmt-observabiity not enabled"
    fi

    #ELK
    echo $AWS_EAST_STEPS | grep mgmt-elk
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/elk.sh $AWS_EAST_MGMT_NAME $AWS_EAST_MGMT_ELASTIC $AWS_EAST_MGMT_KIBANA
    else
        echo "\nmgmt-elk not enabled"
    fi

    #FluentBit
    echo $AWS_EAST_STEPS | grep mgmt-fluentbit
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/fluentbit.sh $AWS_EAST_MGMT_NAME $AWS_EAST_MGMT_ELASTIC
    else
        echo "\nmgmt-fluentbit not enabled"
    fi

    #Harbor
    echo $AWS_EAST_STEPS | grep mgmt-harbor
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/harbor.sh $AWS_EAST_MGMT_NAME $AWS_EAST_MGMT_HARBOR $AWS_EAST_MGMT_NOTARY
    else
        echo "\nmgmt-harbor not enabled"
    fi

    # Workload
    echo $AWS_EAST_STEPS | grep workload-deploy
    testVal=$?
    if [ $testVal -eq 0 ]; then
        # Make sure we are targeted the correct management cluster
        tkg set management-cluster $AWS_EAST_MGMT_NAME 

        cp tkg-extensions/authentication/dex/aws/cluster-template-oidc.yaml ~/.tkg/providers/infrastructure-aws/v0.5.2/

        export OIDC_ISSUER_URL=https://$AWS_EAST_MGMT_DEX_CN
        export OIDC_USERNAME_CLAIM=email
        export OIDC_GROUPS_CLAIM=groups
        # Note: This is different from the documentation as dex-cert-tls does not contain letsencrypt ca
        export DEX_CA=$(cat keys/letsencrypt-ca.pem | gzip | base64)
        yq write ~/.tkg/config.yaml -i "NODE_MACHINE_TYPE" $AWS_WORKLOAD_NODE_TYPE

        tkg create cluster $AWS_EAST_WORKLOAD_NAME --plan=oidc -w $AWS_EAST_WORKLOAD_WORKER -v 6
        retVal=$?
        if [ $retVal -ne 0 ]; then
          return;
        fi

        kubectl apply -f tkg-lab/clusters/wlc-1/default-storage-class.yaml 
        tkg get clusters 
        kubectl get pods -A
        kubectl get sc
    else
        echo "\nworkload-deploy not enabled"
    fi

    kubectx $AWS_EAST_WORKLOAD_NAME-admin@$AWS_EAST_WORKLOAD_NAME

    # Velero
    echo $AWS_EAST_STEPS | grep workload-velero
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/velero.sh $AWS_EAST_WORKLOAD_NAME
    else
        echo "\nworkload-velero not enabled"
    fi

    # TMC
    echo $AWS_EAST_STEPS | grep workload-tmc
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/tmc.sh $AWS_EAST_WORKLOAD_NAME aws
    else
        echo "\nworkload-tmc not enabled"
    fi

    # Ingress
    echo $AWS_EAST_STEPS | grep workload-ingress
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/ingress.sh $AWS_EAST_WORKLOAD_NAME aws $AWS_EAST_WORKLOAD_INGRESS
    else
        echo "\nworkload-ingress not enabled"
    fi

    # Obervability
    echo $AWS_EAST_STEPS | grep workload-observabiity
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/wavefront.sh $AWS_EAST_WORKLOAD_NAME
    else
        echo "\nworkload-observabiity not enabled"
    fi

    # Gangway
    echo $AWS_EAST_STEPS | grep workload-gangway
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/gangway.sh $AWS_EAST_WORKLOAD_NAME $AWS_EAST_MGMT_DEX_CN $AWS_EAST_WORKLOAD_GANGWAY_CN
        ./scripts/inject-dex-client.sh $AWS_EAST_MGMT_NAME $AWS_EAST_WORKLOAD_NAME $AWS_EAST_WORKLOAD_GANGWAY_CN
    else
        echo "\nworkload-gangway not enabled"
    fi

    # FluentBit
    echo $AWS_EAST_STEPS | grep workload-fluentbit
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/fluentbit.sh $AWS_EAST_WORKLOAD_NAME $AWS_EAST_MGMT_ELASTIC
    else
        echo "\nworkload-fluentbit not enabled"
    fi

    # KubeApps
    echo $AWS_EAST_STEPS | grep workload-tac
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/tac.sh $AWS_EAST_WORKLOAD_KUBEAPPS_INGRESS
    else
        echo "\nworkload-tac not enabled"
    fi

    # ArgoCD
    echo $AWS_EAST_STEPS | grep workload-argocd
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/argoCD.sh $AWS_EAST_WORKLOAD_NAME $AWS_EAST_WORKLOAD_ARGOCD_INGRESS
    else
        echo "\nworkload-argocd not enabled"
    fi

    #Enable TMC Namespace
    echo $AWS_EAST_STEPS | grep workload-namespace
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/tmc-namespace.sh $AWS_EAST_WORKLOAD_NAME
    else
        echo "\nworkload-namespace not enabled"
    fi

    # App(s)??
    echo $AWS_EAST_STEPS | grep workload-acme-fitness
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/acme-fitness.sh $AWS_EAST_WORKLOAD_NAME deploy $AWS_EAST_WORKLOAD_ACME_FITNESS_INGRESS
    else
        echo "\nworkload-acme-fitness not enabled"
        #We'll still generate manifests in case we manually deploy later
        ./scripts/acme-fitness.sh $AWS_EAST_WORKLOAD_NAME generate $AWS_EAST_WORKLOAD_ACME_FITNESS_INGRESS
    fi

else
  echo "\nAWS East env not enabled"
fi

if [[ $AWS_WEST = "true" ]]; then
    echo "*********************************"
    echo "Deploying AWS WEST env..."
    echo "*********************************"

    export AWS_REGION=us-west-2
    export AWS_AMI_ID=$AWS_WEST_AMI_ID
    export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm alpha bootstrap encode-aws-credentials)

    echo $AWS_WEST_STEPS | grep mgmt-deploy
    testVal=$?
    if [ $testVal -eq 0 ]; then
        #Prep objects
        mkdir -p keys/
        if [[ ! -f ./keys/aws-west-ssh.pem ]]; then
            aws ec2 delete-key-pair --key-name tkg-west-default
            aws ec2 create-key-pair --key-name tkg-west-default --output json | jq .KeyMaterial -r > keys/aws-west-ssh.pem
        fi

        yq write ~/.tkg/config.yaml -i "AWS_NODE_AZ" $AWS_WEST_NODE_AZ
        yq write ~/.tkg/config.yaml -i "AWS_SSH_KEY_NAME" tkg-west-default
        yq write ~/.tkg/config.yaml -i "NODE_MACHINE_TYPE" $AWS_MGMT_NODE_TYPE

        tkg init --infrastructure=aws --name=$AWS_WEST_MGMT_NAME --plan=dev -v 6
        retVal=$?
        if [ $retVal -ne 0 ]; then
          return;
        fi
        tkg scale cluster $AWS_WEST_MGMT_NAME --namespace tkg-system -w $AWS_WEST_WORKER
        kubectl apply -f tkg-lab/clusters/mgmt/default-storage-class-aws.yaml
        tkg get management-clusters
        kubectl get pods -A
        kubectl get sc
    else
        echo "\nmgmt-deploy not enabled"
    fi

    #Make sure we're targeted to right cluster
    kubectx $AWS_WEST_MGMT_NAME-admin@$AWS_WEST_MGMT_NAME

    #Velero
    echo $AWS_WEST_STEPS | grep mgmt-velero
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/velero.sh $AWS_WEST_MGMT_NAME
    else
        echo "\nmgmt-velero not enabled"
    fi

    #TMC
    echo $AWS_WEST_STEPS | grep mgmt-tmc
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/tmc.sh $AWS_WEST_MGMT_NAME aws
    else
        echo "\nmgmt-tmc not enabled"
    fi

    #Ingress
    echo $AWS_WEST_STEPS | grep mgmt-ingress
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/ingress.sh $AWS_WEST_MGMT_NAME aws $AWS_WEST_MGMT_INGRESS
    else
        echo "\nmgmt-ingress not enabled"
    fi

    #Dex
    echo $AWS_WEST_STEPS | grep mgmt-dex
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/dex.sh $AWS_WEST_MGMT_NAME $AWS_WEST_MGMT_DEX_CN
    else
        echo "\nmgmt-dex not enabled"
    fi

    #Observability
    echo $AWS_WEST_STEPS | grep mgmt-observabiity
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/wavefront.sh $AWS_WEST_MGMT_NAME
    else
        echo "\nmgmt-observabiity not enabled"
    fi

    #ELK
    echo $AWS_WEST_STEPS | grep mgmt-elk
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/elk.sh $AWS_WEST_MGMT_NAME $AWS_WEST_MGMT_ELASTIC $AWS_WEST_MGMT_KIBANA
    else
        echo "\nmgmt-elk not enabled"
    fi

    #FluentBit
    echo $AWS_WEST_STEPS | grep mgmt-fluentbit
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/fluentbit.sh $AWS_WEST_MGMT_NAME $AWS_WEST_MGMT_ELASTIC
    else
        echo "\nmgmt-fluentbit not enabled"
    fi

    #Harbor
    echo $AWS_WEST_STEPS | grep mgmt-harbor
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/harbor.sh $AWS_WEST_MGMT_NAME $AWS_WEST_MGMT_HARBOR $AWS_WEST_MGMT_NOTARY
    else
        echo "\nmgmt-harbor not enabled"
    fi

    # Workload
    echo $AWS_WEST_STEPS | grep workload-deploy
    testVal=$?
    if [ $testVal -eq 0 ]; then
        # Make sure we are targeted the correct management cluster
        tkg set management-cluster $AWS_WEST_MGMT_NAME 

        cp tkg-extensions/authentication/dex/aws/cluster-template-oidc.yaml ~/.tkg/providers/infrastructure-aws/v0.5.2/

        export OIDC_ISSUER_URL=https://$AWS_WEST_MGMT_DEX_CN
        export OIDC_USERNAME_CLAIM=email
        export OIDC_GROUPS_CLAIM=groups
        # Note: This is different from the documentation as dex-cert-tls does not contain letsencrypt ca
        export DEX_CA=$(cat keys/letsencrypt-ca.pem | gzip | base64)
        yq write ~/.tkg/config.yaml -i "NODE_MACHINE_TYPE" $AWS_WORKLOAD_NODE_TYPE

        tkg create cluster $AWS_WEST_WORKLOAD_NAME --plan=oidc -w $AWS_WEST_WORKLOAD_WORKER -v 6
        retVal=$?
        if [ $retVal -ne 0 ]; then
          return;
        fi

        kubectl apply -f tkg-lab/clusters/wlc-1/default-storage-class.yaml 
        tkg get clusters 
        kubectl get pods -A
        kubectl get sc
    else
        echo "\nworkload-deploy not enabled"
    fi

    kubectx $AWS_WEST_WORKLOAD_NAME-admin@$AWS_WEST_WORKLOAD_NAME

    # Velero
    echo $AWS_WEST_STEPS | grep workload-velero
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/velero.sh $AWS_WEST_WORKLOAD_NAME
    else
        echo "\nworkload-velero not enabled"
    fi

    # TMC
    echo $AWS_WEST_STEPS | grep workload-tmc
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/tmc.sh $AWS_WEST_WORKLOAD_NAME aws
    else
        echo "\nworkload-tmc not enabled"
    fi

    # Ingress
    echo $AWS_WEST_STEPS | grep workload-ingress
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/ingress.sh $AWS_WEST_WORKLOAD_NAME aws $AWS_WEST_WORKLOAD_INGRESS
    else
        echo "\nworkload-ingress not enabled"
    fi

    # Obervability
    echo $AWS_WEST_STEPS | grep workload-observabiity
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/wavefront.sh $AWS_WEST_WORKLOAD_NAME
    else
        echo "\nworkload-observabiity not enabled"
    fi

    # Gangway
    echo $AWS_WEST_STEPS | grep workload-gangway
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/gangway.sh $AWS_WEST_WORKLOAD_NAME $AWS_WEST_MGMT_DEX_CN $AWS_WEST_WORKLOAD_GANGWAY_CN
        ./scripts/inject-dex-client.sh $AWS_WEST_MGMT_NAME $AWS_WEST_WORKLOAD_NAME $AWS_WEST_WORKLOAD_GANGWAY_CN
    else
        echo "\nworkload-gangway not enabled"
    fi

    # FluentBit
    echo $AWS_WEST_STEPS | grep workload-fluentbit
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/fluentbit.sh $AWS_WEST_WORKLOAD_NAME $AWS_WEST_MGMT_ELASTIC
    else
        echo "\nworkload-fluentbit not enabled"
    fi

    # KubeApps
    echo $AWS_WEST_STEPS | grep workload-tac
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/tac.sh $AWS_WEST_WORKLOAD_KUBEAPPS_INGRESS
    else
        echo "\nworkload-tac not enabled"
    fi

    # ArgoCD
    echo $AWS_WEST_STEPS | grep workload-argocd
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/argoCD.sh $AWS_WEST_WORKLOAD_NAME $AWS_WEST_WORKLOAD_ARGOCD_INGRESS
    else
        echo "\nworkload-argocd not enabled"
    fi

    #Enable TMC Namespace
    echo $AWS_WEST_STEPS | grep workload-namespace
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/tmc-namespace.sh $AWS_WEST_WORKLOAD_NAME
    else
        echo "\nworkload-namespace not enabled"
    fi

    # App(s)??
    echo $AWS_WEST_STEPS | grep workload-acme-fitness
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/acme-fitness.sh $AWS_WEST_WORKLOAD_NAME deploy $AWS_WEST_WORKLOAD_ACME_FITNESS_INGRESS
    else
        echo "\nworkload-acme-fitness not enabled"
        #We'll still generate manifests in case we manually deploy later
        ./scripts/acme-fitness.sh $AWS_WEST_WORKLOAD_NAME generate $AWS_WEST_WORKLOAD_ACME_FITNESS_INGRESS
    fi
else
  echo "\nAWS West env not enabled"
fi

if [[ $VMW = "true" ]]; then
    echo "*********************************"
    echo "Deploying vSphere env..."
    echo "*********************************"
    

    echo $VMW_STEPS | grep mgmt-deploy
    testVal=$?
    if [ $testVal -eq 0 ]; then        
        #Prep objects
        mkdir -p keys/
        if [[ ! -f ./keys/tkg_rsa ]]; then
            ssh-keygen -t rsa -b 4096 -f ./keys/tkg_rsa -q -N ""
            ssh-add ./keys/tkg_rsa
        fi
        

        AUTH_KEY=`cat ./keys/tkg_rsa.pub`
        yq write ~/.tkg/config.yaml -i "VSPHERE_SERVER" $VMW_VSPHERE_SERVER
        yq write ~/.tkg/config.yaml -i "VSPHERE_USERNAME" $VMW_VSPHERE_USERNAME
        yq write ~/.tkg/config.yaml -i "VSPHERE_PASSWORD" $VMW_VSPHERE_PASSWORD
        yq write ~/.tkg/config.yaml -i "VSPHERE_DATACENTER" $VMW_VSPHERE_DATACENTER
        yq write ~/.tkg/config.yaml -i "VSPHERE_DATASTORE" $VMW_VSPHERE_DATASTORE
        yq write ~/.tkg/config.yaml -i "VSPHERE_NETWORK" $VMW_VSPHERE_NETWORK
        yq write ~/.tkg/config.yaml -i "VSPHERE_RESOURCE_POOL" $VMW_VSPHERE_RESOURCE_POOL
        yq write ~/.tkg/config.yaml -i "VSPHERE_FOLDER" $VMW_VSPHERE_FOLDER
        yq write ~/.tkg/config.yaml -i "VSPHERE_TEMPLATE" $VMW_VSPHERE_TEMPLATE
        yq write ~/.tkg/config.yaml -i "VSPHERE_HAPROXY_TEMPLATE" $VMW_VSPHERE_HAPROXY_TEMPLATE
        yq write ~/.tkg/config.yaml -i "VSPHERE_DISK_GIB" $VMW_VSPHERE_DISK_GIB
        yq write ~/.tkg/config.yaml -i "VSPHERE_NUM_CPUS" $VMW_VSPHERE_NUM_CPUS
        yq write ~/.tkg/config.yaml -i "VSPHERE_MEM_MIB" $VMW_VSPHERE_MEM_MIB
        yq write ~/.tkg/config.yaml -i "VSPHERE_SSH_AUTHORIZED_KEY" $AUTH_KEY
        yq write ~/.tkg/config.yaml -i "SERVICE_CIDR" $VMW_SERVICE_CIDR
        yq write ~/.tkg/config.yaml -i "CLUSTER_CIDR" $VMW_CLUSTER_CIDR

        tkg init --infrastructure=vsphere --name $VMW_MGMT_NAME --plan=dev -v 6
        retVal=$?
        if [ $retVal -ne 0 ]; then
          return;
        fi
        tkg scale cluster $VMW_MGMT_NAME --namespace tkg-system -w $VMW_MGMT_WORKER
        kubectl apply -f tkg-lab/clusters/mgmt/default-storage-class-vsphere.yaml
        tkg get management-clusters
        kubectl get pods -A
        kubectl get sc
    else
        echo "\nmgmt-deploy not enabled"
    fi

    #Make sure we're targeted to right cluster
    kubectx $VMW_MGMT_NAME-admin@$VMW_MGMT_NAME

    #mgmt-velero
    echo $VMW_STEPS | grep mgmt-velero
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/velero.sh $VMW_MGMT_NAME
    else
        echo "\nmgmt-velero not enabled"
    fi

    #mgmt-tmc
    echo $VMW_STEPS | grep mgmt-tmc
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/tmc.sh $VMW_MGMT_NAME vsphere
    else
        echo "\nmgmt-tmc not enabled"
    fi

    #mgmt-metallb
    echo $VMW_STEPS | grep mgmt-metallb
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/metal-lb.sh $VMW_MGMT_NAME $VMW_MGMT_METAL_LB_IP_RANGE
    else
        echo "\nmgmt-tmc not enabled"
    fi

    #mgmt-ingress
    echo $VMW_STEPS | grep mgmt-ingress
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/ingress.sh $VMW_MGMT_NAME vsphere $VMW_MGMT_INGRESS
    else
        echo "\nmgmt-ingress not enabled"
    fi

    #mgmt-observabiity
    echo $VMW_STEPS | grep mgmt-observabiity
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/wavefront.sh $VMW_MGMT_NAME
    else
        echo "\nmgmt-observabiity not enabled"
    fi

    #mgmt-elk
    echo $VMW_STEPS | grep mgmt-elk
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/elk.sh $VMW_MGMT_NAME $VMW_MGMT_ELASTIC $VMW_MGMT_KIBANA
    else
        echo "\nmgmt-elk not enabled"
    fi

    #mgmt-fluentbit
    echo $VMW_STEPS | grep mgmt-fluentbit
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/fluentbit.sh $VMW_MGMT_NAME $VMW_MGMT_ELASTIC
    else
        echo "\nmgmt-fluentbit not enabled"
    fi

    #mgmt-dex
    echo $VMW_STEPS | grep mgmt-dex
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/dex.sh $VMW_MGMT_NAME $VMW_MGMT_DEX_CN
    else
        echo "\nmgmt-dex not enabled"
    fi

    #mgmt-harbor
    echo $VMW_STEPS | grep mgmt-harbor
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/harbor.sh $VMW_MGMT_NAME $VMW_MGMT_HARBOR $VMW_MGMT_NOTARY
    else
        echo "\nmgmt-harbor not enabled"
    fi

    #workload-deploy
    echo $VMW_STEPS | grep workload-deploy
    testVal=$?
    if [ $testVal -eq 0 ]; then
        # Make sure we are targeted the correct management cluster
        tkg set management-cluster $VMW_MGMT_NAME 

        cp tkg-extensions/authentication/dex/vsphere/cluster-template-oidc.yaml ~/.tkg/providers/infrastructure-vsphere/v0.6.3/

        export OIDC_ISSUER_URL=https://$VMW_MGMT_DEX_CN
        export OIDC_USERNAME_CLAIM=email
        export OIDC_GROUPS_CLAIM=groups
        # Note: This is different from the documentation as dex-cert-tls does not contain letsencrypt ca
        export DEX_CA=$(cat keys/letsencrypt-ca.pem | gzip | base64)

        tkg create cluster $VMW_WORKLOAD_NAME --plan=oidc -w $VMW_WORKLOAD_WORKER -v 6
        retVal=$?
        if [ $retVal -ne 0 ]; then
          return;
        fi

        kubectl apply -f tkg-lab/clusters/mgmt/default-storage-class-vsphere.yaml
        tkg get clusters 
        kubectl get pods -A
        kubectl get sc
    else
        echo "\nworkload-deploy not enabled"
    fi

    #Make sure we're targeted to right cluster
    kubectx $VMW_WORKLOAD_NAME-admin@$VMW_WORKLOAD_NAME

    #workload-velero
    echo $VMW_STEPS | grep workload-velero
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/velero.sh $VMW_WORKLOAD_NAME
    else
        echo "\nworkload-velero not enabled"
    fi

    #workload-tmc
    echo $VMW_STEPS | grep workload-tmc
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/tmc.sh $VMW_WORKLOAD_NAME vsphere
    else
        echo "\nworkload-tmc not enabled"
    fi

    #workload-metallb
    echo $VMW_STEPS | grep workload-metallb
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/metal-lb.sh $VMW_WORKLOAD_NAME $VMW_WORKLOAD_METAL_LB_IP_RANGE
    else
        echo "\nworkload-tmc not enabled"
    fi

    #workload-ingress
    echo $VMW_STEPS | grep workload-ingress
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/ingress.sh $VMW_WORKLOAD_NAME vsphere $VMW_WORKLOAD_INGRESS
    else
        echo "\nworkload-ingress not enabled"
    fi

    #workload-gangway
    echo $VMW_STEPS | grep workload-gangway
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/gangway.sh $VMW_WORKLOAD_NAME $VMW_MGMT_DEX_CN $VMW_WORKLOAD_GANGWAY_CN
        ./scripts/inject-dex-client.sh $VMW_MGMT_NAME $VMW_WORKLOAD_NAME $VMW_WORKLOAD_GANGWAY_CN
    else
        echo "\nworkload-gangway not enabled"
    fi

    #workload-observabiity
    echo $VMW_STEPS | grep workload-observabiity
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/wavefront.sh $VMW_WORKLOAD_NAME
    else
        echo "\nworkload-observabiity not enabled"
    fi
    #workload-fluentbit
    echo $VMW_STEPS | grep workload-fluentbit
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/fluentbit.sh $VMW_WORKLOAD_NAME $VMW_MGMT_ELASTIC
    else
        echo "\nworkload-fluentbit not enabled"
    fi

    #workload-tac
    echo $VMW_STEPS | grep workload-tac
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/tac.sh $VMW_WORKLOAD_KUBEAPPS_INGRESS
    else
        echo "\nworkload-tac not enabled"
    fi

    #workload-argocd
    echo $VMW_STEPS | grep workload-argocd
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/argoCD.sh $VMW_WORKLOAD_NAME $VMW_WORKLOAD_ARGOCD_INGRESS
    else
        echo "\nworkload-argocd not enabled"
    fi

    #Enable TMC namespace
    echo $VMW_STEPS | grep workload-namespace
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/tmc-namespace.sh $VMW_WORKLOAD_NAME
    else
        echo "\nworkload-namespace not enabled"
    fi

    #Apps???
    echo $VMW_STEPS | grep workload-acme-fitness
    testVal=$?
    if [ $testVal -eq 0 ]; then
        ./scripts/acme-fitness.sh $VMW_WORKLOAD_NAME deploy $VMW_WORKLOAD_ACME_FITNESS_INGRESS
    else
        echo "\nworkload-acme-fitness not enabled"
        #We'll still generate manifests in case we manually deploy later
        ./scripts/acme-fitness.sh $VMW_WORKLOAD_NAME generate $VMW_WORKLOAD_ACME_FITNESS_INGRESS
    fi
else
  echo "\nvSphere env not enabled"
fi