#!/bin/bash
# 
echo "#########################################################################"
echo "## This script create self signed ssl cert for dashbase and presto     ##"
echo "## The created self signed certs are storing as K8s secrets            ##"
echo "## There are three arguments need to provide to run this script        ##"
echo "##                                                                     ##"
echo "## --dashbase   means creating dashbase certs                          ##"
echo "## --presto     means creating presto certs                            ##"
echo "## --namespace  input your namespace with equal sign                   ##"
echo "##                                                                     ##"
echo "##  Example: create  both dashbase and presto ssl certs                ##" 
echo "##  ./create-sslcerts.sh  --dashbase --presto --namespace=mynamespace  ##"
echo "##                                                                     ##"
echo "##  Example: just list dashbase/presto keystore password               ##"
echo "##  ./create-sslcerts.sh  --namespace=mynamespace                      ##"
echo "##                                                                     ##"
echo "##  the created pem, keystore and crt files are in ~/data              ##"
echo "#########################################################################"
#
mkdir -p ~/data
rm -rf ~/data/*.pem
rm -rf ~/data/https-presto.yaml
rm -rf ~/data/https-dashbase.yaml

DASH_FLAG="false"
PRESTO_FLAG="false"
NAMESPACE="undefined"
CMDS="curl tar unzip git"

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

function fail_if_empty() {
  [[ -z "$2" ]] && log_fatal "Parameter $1 must have a value."
  return 0
}


echo "$@" > /tmp/setup_arguments
echo "$#" > /tmp/no_arguments

while [[ $# -gt 0 ]]; do
  PARAM=${1%%=*}
  [[ "$1" == *"="* ]] && VALUE=${1#*=} || VALUE=""
  log_info "Parsing ($1)"
  shift 1

  case $PARAM in
  --namespace)
    fail_if_empty "$PARAM" "$VALUE"
    NAMESPACE=$VALUE
    ;;
  --dashbase)
    DASH_FLAG="true"
    ;;
  --presto)
    PRESTO_FLAG="true"
    ;;
  *)
    log_fatal "Unknown parameter ($PARAM) with ${VALUE:-no value}"
    ;;
  esac
done

# check if namespace is not provided
check_namespace_input() {
if [ "$NAMESPACE" == "undefined" ]; then
   log_fatal "You need to provide namespace flag e.g. --namespace=mynamespace"
else
   log_info "Entered namespace is $NAMESPACE"
   log_info "Dashbase flag is $DASH_FLAG"
   log_info "Presto flag is $PRESTO_FLAG"
fi
}


# check required commands
check_commands() {
  for x in $CMDS
     do command -v "$x" > /dev/null && continue || { log_fatal "$x command not found."; }
  done
}

# create dashbase SSL cert
create_dashbase_sslcert() {
  echo "deploy dashbase with secure connection internally"
  echo "creating dashbase internal SSL cert, key, keystore, keystore password"
  cd ~/data ; ~/data/https_dashbase.sh $NAMESPACE
  kubectl apply -f  ~/data/https-dashbase.yaml -n $NAMESPACE
  kubectl get secrets -n $NAMESPACE | grep -E 'dashbase-cert|dashbase-key'
  CHKDSECRETS=$(kubectl get secrets -n $NAMESPACE | grep -E -c 'dashbase-cert|dashbase-key')
  if [ "$CHKDSECRETS" -eq "4" ]; then
    echo "dashbase SSL cert, key, keystore and keystore password are created"
  else
    echo "Error to create dashbase SSL cert, key, keystore, and keystore password"
  fi
}

# create presto SSL cert
create_presto_sslcert() {
  echo "setup presto internal SSL cert, key, keystore, keystore password"
  cd ~/data ; ~/data/https_presto2.sh $NAMESPACE
  kubectl apply -f ~/data/https-presto.yaml -n $NAMESPACE
  kubectl get secrets -n $NAMESPACE | grep -E 'presto-cert|presto-key'
  CHKPSECRETS=$(kubectl get secrets -n $NAMESPACE | grep -c 'presto')
  if [ "$CHKPSECRETS" -eq "4" ]; then
    echo "presto SSL cert, key, keystore and keystore password are created"
  else
    echo "Error to create presto SSL cert, key, keystore, and keystore password"
  fi
}

# main process start below this line
check_namespace_input
check_commands

# Download the required scripts and templates

curl -k https://dashbase-public.s3-us-west-1.amazonaws.com/scripts/https-dashbase-template.yaml -o ~/data/https-dashbase-template.yaml
curl -k https://dashbase-public.s3-us-west-1.amazonaws.com/scripts/https-presto-template.yaml -o ~/data/https-presto-template.yaml
curl -k https://dashbase-public.s3-us-west-1.amazonaws.com/scripts/https_dashbase.sh -o ~/data/https_dashbase.sh
curl -k https://dashbase-public.s3-us-west-1.amazonaws.com/scripts/https_presto2.sh -o ~/data/https_presto2.sh

chmod a+x ~/data/https_dashbase.sh
chmod a+x ~/data/https_presto2.sh


# create  dashbase cert
if [ "$DASH_FLAG" = "true" ]; then
   log_info "Creating dashbase SSL cert"
   create_dashbase_sslcert
else
   log_info "dashbase flag is $DASH_FLAG ; not creating the dashbase self-signed cert"
fi

# create presto cert
if [ "$PRESTO_FLAG" = "true" ]; then
   log_info "Creating dashbase SSL cert"
   create_presto_sslcert
else
   log_info "dashbase flag is $PRESTO_FLAG ; not creating the presto self-signed cert"
fi

# retrive the dashbase and presto keystore password

kubectl get secrets presto-keystore-password -n $NAMESPACE -o yaml |grep "keystore_password:" |awk '{ print $2}' |base64 --decode > presto-keypass
kubectl get secrets dashbase-keystore-password -n $NAMESPACE -o yaml |grep "keystore_password:" |awk '{ print $2}' |base64 --decode > dashbase-keypass
PKEYPASS=$(cat presto-keypass)
DASHPASS=$(cat dashbase-keypass)

echo "the dashbase keystore password = $DASHPASS"
echo "the presto keystore password = $PKEYPASS"

