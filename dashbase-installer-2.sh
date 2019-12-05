#!/bin/bash

PLATFORM="undefined"
#SUBDOMAIN="undefined"

# preflight checks
echo "OS type running this script is $OSTYPE"

CMDS="kubectl tar curl"
for x in $CMDS
   do  command -v $x > /dev/null && continue || { echo "This script requires $x command and is not found."; exit 1; }
done

function log_info() {
  echo -e "INFO *** $*"
}

function log_warning() {
  echo -e "WARN *** $*"
}

function log_fatal() {
  echo -e "FATAL *** $*"
  exit 1
}

function fail_if_empty() {
  [[ -z "$2" ]] && log_fatal "Parameter $1 must have a value."
  return 0
}

echo "$@" > setup_arguments
echo "$#" > no_arguments
#SET_ARG=`cat setup_arguments`
#NUM_ARG=`cat no_arguments`

while [[ $# -gt 0 ]]; do
  PARAM=${1%%=*}
  [[ "$1" == *"="* ]] && VALUE=${1#*=} || VALUE=""
  log_info "Parsing ($1): $PARAM with ${VALUE:-no value}"
  shift 1

  case $PARAM in
    --subdomain)
      fail_if_empty "$PARAM" "$VALUE"
      SUBDOMAIN=$VALUE
      ;;
    --platform)
      fail_if_empty "$PARAM" "$VALUE"
      PLATFORM=$VALUE
      ;;
    --ingress)
      INGRESS_FLAG="true"
      ;;
    --nopresto)
      NOPRESTO_FLAG="true"
      ;;
    --nossl)
      NOSSL_FLAG="true"
      ;;
    *)
      log_warning "Unknown parameter ($PARAM) with ${VALUE:-no value}"
      ;;
  esac
done

# check entered platform in dashbase value yaml  file

check_platform() {
   if [[ "$PLATFORM" == "undefined"  ||  -z "$PLATFORM" ]]; then log_fatal "--platform is required"
   elif [ "$PLATFORM" == "aws" ]; then echo "entered plaform type is $PLATFORM"
   elif [ "$PLATFORM" == "azure" ]; then echo "entered plaform type is $PLATFORM"
   elif [ "$PLATFORM" == "gce" ]; then echo "entered plaform type is $PLATFORM"
   else
     log_fatal "Incorrect platform type, and platform type should be either aws, gce, or azure"
   fi
}

check_ingress_subdomain() {
  if [[ "$INGRESS_FLAG" == "true" && -z "$SUBDOMAIN" ]]; then log_fatal "--subomain is required when using --ingress flag"
  elif [[  "$INGRESS_FLAG" == "true"  && -n "$SUBDOMAIN" ]]; then echo "entered subdomain is $SUBDOMAIN"
  fi
}

check_platform
check_ingress_subdomain

# create namespace dashbase and admin service account for installation
kubectl create namespace dashbase
kubectl create serviceaccount dashadmin -n dashbase
kubectl create clusterrolebinding admin-user-binding --clusterrole=cluster-admin --serviceaccount=dashbase:dashadmin

# Download and install installer helper statefulset yaml file
curl -k https://dashbase-public.s3-us-west-1.amazonaws.com/admindash-sts.yaml -o admindash-sts.yaml
kubectl apply -f admindash-sts.yaml -n dashbase
#kubectl wait --for=condition=available sts/admindash -n dashbase

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

# update dashbase-values.yaml for platform choice and subdomain

if [ -n "$SUBDOMAIN" ]; then
  echo "update ingress subdomain in dashbase-values.yaml file"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "sed -i 's|test.dashbase.io|$SUBDOMAIN|' dashbase-values.yaml"
elif [ -z "$SUBDOMAIN" ]; then
  echo "no input on --subdomain will use default which is test.dashbase.io"
fi

# update platform type in dashbase-values.yaml file

if [ $PLATFORM == aws ]; then echo "use default platform type aws in dashbase-values.yaml"
elif [ $PLATFORM == gce ]; then
  echo "update platform type gce in dashbase-values.yaml"
  kubectl exec  -it admindash-0 -n dashbase -- sed -i 's/aws/gce/' dashbase-values.yaml
elif [ $PLATFORM == azure ]; then
  echo "update platform type azure in dashbase-values.yaml"
  kubectl exec  -it admindash-0 -n dashbase -- sed -i 's/aws/azure/' dashbase-values.yaml
fi

# update default subdomain test.dashbase.io for Ingress if using Ingress to expose web and table endpoints
# kubectl exec -it admindash-0 -n dashbase -- bash -c "sed -i 's|test.dashbase.io|$SUBDOMAIN|' dashbase-values.yaml"

# check if non secure dashbase deployment is input by user
if [ $NOSSL_FLAG == true ]; then
  echo "deploy dashbase with non secure connection, and this deployment will skip presto setup"
  kubectl exec -it admindash-0 -n dashbase -- sed -i "s|https: true|https: false|" dashbase-values.yaml
else
  echo "deploy dashbase with secure connection internally"
fi

#if [ -z $2 ] || [ $2 == https ]; then
#  echo "deploy dashbase with secure connection internally"
#elif [ $2 == http ]; then
#  echo "deploy dashbase with non secure connection, and this deployment will skip presto setup"
#  kubectl exec -it admindash-0 -n dashbase -- sed -i "s|https: true|https: false|" dashbase-values.yaml
#fi

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

