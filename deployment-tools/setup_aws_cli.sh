#!/bin/bash

AWS_ACCESS_KEY="undefined"
AWS_SECRET_ACCESS_KEY="undefined"
REGION="us-east-2"

# log functions and input flag setup
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

echo "$@" >setup_arguments
echo "$#" >no_arguments

while [[ $# -gt 0 ]]; do
  PARAM=${1%%=*}
  [[ "$1" == *"="* ]] && VALUE=${1#*=} || VALUE=""
  log_info "Parsing ($1)"
  shift 1

  case $PARAM in
  --aws_access_key)
    fail_if_empty "$PARAM" "$VALUE"
    AWS_ACCESS_KEY=$VALUE
    ;;
  --aws_secret_access_key)
    fail_if_empty "$PARAM" "$VALUE"
    AWS_SECRET_ACCESS_KEY=$VALUE
    ;;
  --region)
    fail_if_empty "$PARAM" "$VALUE"
    REGION=$VALUE
    ;;
  *)
    log_warning "Unknown parameter ($PARAM) with ${VALUE:-no value}"
    ;;
  esac
done

log_info "Install AWS CLI"
curl https://s3.amazonaws.com/aws-cli/awscli-bundle-1.16.188.zip -o awscli-bundle.zip
unzip awscli-bundle.zip
awscli-bundle/install  -i /usr/local/aws -b /usr/local/bin/aws

log_info "Configure AWS CLI"
/usr/local/bin/aws --version
/usr/local/bin/aws --profile default configure set aws_access_key_id $AWS_ACCESS_KEY
/usr/local/bin/aws --profile default configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
/usr/local/bin/aws --profile default configure set region $REGION

/usr/local/bin/aws configure list

curl -k https://storage.googleapis.com/kubernetes-release/release/v1.17.0/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl
chmod a+x /usr/local/bin/kubectl

CLUSTERNAME=$(aws eks list-clusters --region $REGION |grep mydash |sed -e 's/\"//g' |sed -e 's/^[ \t]*//')
echo "The dashbase K8s cluster name is $CLUSTERNAME"

aws eks --region "$REGION" update-kubeconfig --name "$CLUSTERNAME"

logi_info "Checking K8s nodes"
/usr/local/bin/kubectl get nodes

log_info "Checking current pods on the K8s cluster"
/usr/local/bin/kubectl get pods --all-namespaces

