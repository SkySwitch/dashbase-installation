#!/bin/bash

SUBDOMAIN=$1
echo "entered subdomain is $SUBDOMAIN"

# create namespace dashbase and admin service account for installation
kubectl create namespace dashbase
kubectl create serviceaccount dashadmin -n dashbase
kubectl create clusterrolebinding admin-user-binding --clusterrole=cluster-admin --serviceaccount=dashbase:dashadmin

# Download and install installer helper statefulset yaml file
curl -k https://dashbase-public.s3-us-west-1.amazonaws.com/admindash-sts.yaml -o admindash-sts.yaml
kubectl apply -f admindash-sts.yaml -n dashbase

# kubectl wait --for=condition=available sts/admindash -n dashbase
sleep 100

# create tiller service account in kube-system namespace
kubectl exec -it admindash-0 -n dashbase -- bash -c "wget https://raw.githubusercontent.com/dashbase/dashbase-installation/master/dashbase/rbac-config.yaml"
kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl apply -f rbac-config.yaml"
# start tiller
kubectl exec -it admindash-0 -n dashbase -- bash -c "helm init --service-account tiller"
kubectl wait --for=condition=available deployment/tiller-deploy -n kube-system

# check helm
kubectl exec -it admindash-0 -n dashbase -- bash -c "helm ls"

# adding dashbase helm repo
kubectl exec -it admindash-0 -n dashbase -- bash -c "helm repo add dashbase https://charts.dashbase.io"
kubectl exec -it admindash-0 -n dashbase -- bash -c "helm repo list"

# download dashbase setup yaml files
kubectl exec -it admindash-0 -n dashbase -- bash -c "wget https://dashbase-public.s3-us-west-1.amazonaws.com/dashbase_setup.tar"
kubectl exec -it admindash-0 -n dashbase -- bash -c "tar -xvf dashbase_setup.tar"

# create storageclass
kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl apply -f dashbase-data-aws.yaml -n dashbase"
kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl apply -f dashbase-meta-aws.yaml -n dashbase"
kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl get storageclass"

# update default subdomain test.dashbase.io for Ingress if using Ingress to expose web and table endpoints
kubectl exec -it admindash-0 -n dashbase -- bash -c "sed -i 's|test.dashbase.io|$SUBDOMAIN|' dashbase-values.yaml"

# check if non secure dashbase deployment is input by user
if [ -z $2 ] || [ $2 == https ]; then
  echo "deploy dashbase with secure connection internally"
elif [ $2 == http ]; then
  echo "deploy dashbase with non secure connection, and this deployment will skip presto setup"
  kubectl exec -it admindash-0 -n dashbase -- sed -i "s|https: true|https: false|" dashbase-values.yaml
fi

# create dashbase deployment via helm install
kubectl exec -it admindash-0 -n dashbase -- bash -c "helm install dashbase/dashbase -f dashbase-values.yaml --name dashbase --namespace dashbase --devel --debug --no-hooks"

# check dashbase deployment  (WIP)
# use sleep to make time for dashbase pods to come until check function ready
sleep 200
kubectl get po -n dashbase

# Expose endpoints via ingress
kubectl exec -it admindash-0 -n dashbase -- bash -c "helm install stable/nginx-ingress --name nginx-ingress --namespace dashbase"
kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl get po -n dashbase |grep ingress"

# get the exposed IP address from nginx ingress controller
EXTERNAL_IP=$(kubectl exec -it admindash-0 -n dashbase -- kubectl get svc nginx-ingress-controller -n dashbase |tail -n +2 |awk '{ print $4}')
echo "the exposed IP address for web and tables endpoint is $EXTERNAL_IP"
