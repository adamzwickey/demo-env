# bin/bash

ARGO_PWD=`kubectl get po -n argocd | grep argocd-server| awk '{print $1}'`
echo "ArgoCD Username: admin"
echo "ArgoCD Password: $ARGO_PWD"