# bin/bash

source keys/env.sh

if [[ $AWS_EAST = "true" ]]; then
    echo "*********************************"
    echo "Destroying AWS EAST env..."
    echo "*********************************"

    export AWS_REGION=us-east-2
    export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm alpha bootstrap encode-aws-credentials)

    #Workload First
    tmc cluster delete $TMC_CLUSTER_GROUP-$AWS_EAST_WORKLOAD_NAME --force
    tkg set management-cluster $AWS_EAST_MGMT_NAME
    tkg delete cluster $AWS_EAST_WORKLOAD_NAME --yes 
    #Wait to be deleted
    while tkg get cluster | grep $AWS_EAST_WORKLOAD_NAME  ; [ $? -ne 1 ]; do
	    echo Cluster still deleteing
	    sleep 5s
    done

    #Then Management
    tmc cluster delete $TMC_CLUSTER_GROUP-$AWS_EAST_MGMT_NAME --force
    tkg set management-cluster $AWS_EAST_MGMT_NAME
    retVal=$?
    if [ $retVal -ne 0 ]; then
        return;
    fi
    tkg delete management-cluster -y

else
  echo "\nAWS EAST env not enabled"
fi

if [[ $AWS_WEST = "true" ]]; then
    echo "*********************************"
    echo "Destroying AWS WEST env..."
    echo "*********************************"

    export AWS_REGION=us-west-2
    export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm alpha bootstrap encode-aws-credentials)

    #Workload First
    tmc cluster delete $TMC_CLUSTER_GROUP-$AWS_WEST_WORKLOAD_NAME --force
    tkg set management-cluster $AWS_WEST_MGMT_NAME
    tkg delete cluster $AWS_WEST_WORKLOAD_NAME --yes 
    #Wait to be deleted
    while tkg get cluster | grep $AWS_WEST_WORKLOAD_NAME  ; [ $? -ne 1 ]; do
	    echo Cluster still deleteing
	    sleep 5s
    done

    #Then Management
    tmc cluster delete $TMC_CLUSTER_GROUP-$AWS_WEST_MGMT_NAME --force
    tkg set management-cluster $AWS_WEST_MGMT_NAME
    retVal=$?
    if [ $retVal -ne 0 ]; then
        return;
    fi
    tkg delete management-cluster -y

else
  echo "\nAWS WEST env not enabled"
fi

if [[ $VMW = "true" ]]; then
    echo "*********************************"
    echo "Destroying vSphere env..."
    echo "*********************************"
    export AWS_REGION=us-east-2
    export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm alpha bootstrap encode-aws-credentials)

    #Workload First
    tmc cluster delete $TMC_CLUSTER_GROUP-$VMW_WORKLOAD_NAME --force
    tkg set management-cluster $VMW_MGMT_NAME
    tkg delete cluster $VMW_WORKLOAD_NAME --yes 
    #Wait to be deleted
    while tkg get cluster | grep $VMW_WORKLOAD_NAME  ; [ $? -ne 1 ]; do
	    echo Cluster still deleteing
	    sleep 5s
    done

    #Then Management
    tmc cluster delete $TMC_CLUSTER_GROUP-$VMW_MGMT_NAME --force
    tkg set management-cluster $VMW_MGMT_NAME
    retVal=$?
    if [ $retVal -ne 0 ]; then
        return;
    fi
    tkg delete management-cluster -y
else
  echo "\nvSphere env not enabled"
fi