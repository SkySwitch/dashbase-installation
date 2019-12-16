#!/bin/bash

# Set default environment values.
PLATFORM="undefined"
NAMESPACE="dashbase"
RELEASE="dashbase"
VERSION="1.0.2"
VALUES_YAML='./values.yml'

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

CMDS="kubectl tar curl"
for x in $CMDS
   do  command -v $x > /dev/null && continue || { echo "This script requires $x command and is not found."; exit 1; }
done

# Load user input PARAM
    while [[ $# -gt 0 ]]; do
    PARAM=${1%%=*}
    [[ "$1" == *"="* ]] && VALUE=${1#*=} || VALUE=""
    log_info "Parsing ($1): $PARAM with ${VALUE:-no value}"
    shift 1
    case $PARAM in
      "--username" )
        fail_if_empty "$PARAM" "$VALUE"
        USERNAME=$VALUE
        ;;
      "--license" )
        fail_if_empty "$PARAM" "$VALUE"
        LICENSE=$VALUE
        ;;
      "--namespace" )
        fail_if_empty "$PARAM" "$VALUE"
        NAMESPACE=$VALUE
        ;;
      "--file" )
        fail_if_empty "$PARAM" "$VALUE"
        VALUES_YAML=$VALUE
        ;;
      "--name" )
        fail_if_empty "$PARAM" "$VALUE"
        RELEASE=$VALUE
        ;;
      "--version" )
        fail_if_empty "$PARAM" "$VALUE"
        VERSION=$VALUE
        ;;
        *)
        echo "Unknown parameter ($PARAM) with ${VALUE:-no value}"
        ;;
      esac
    done

# Update values.yaml file
    sed -i "s|username:.*|username: $USERNAME|" $VALUES_YAML
    sed -i "s|license:.*|license: $LICENSE|" $VALUES_YAML

# Check Running environment
RUNNING_RELEASE=$(helm ls  |grep install |awk '{print $1}')
RUNNING_NAMESPACE=$(helm ls |grep install | awk '{print $11}')
if [[ "$RUNNING_RELEASE" != "$RELEASE" ]]; then
    log_fatal "Release named $RELEASE is not running, please check."
    exit
  if [ "$RUNNING_NAMESPACE" != "$NAMESPACE" ]; then
    log_fatal "Namespace $NAMESPACE not match your release, please check."
    exit
  fi
fi

log_info "helm repo add chartmuseum https://charts.dashbase.io"
helm repo add chartmuseum https://charts.dashbase.io
log_info "helm upgrade $RELEASE chartmuseum/dashbase -f $VALUES_YAML --namespace $NAMESPACE -i  --version $VERSION"
helm upgrade $RELEASE chartmuseum/dashbase -f $VALUES_YAML --namespace $NAMESPACE -i  --version $VERSION &> /dev/null

log_info "kubectl delete pod $(kubectl get pod -n install | grep api | awk '{print $1}') -n $NAMESPACE"
kubectl delete pod $(kubectl get pod -n install | grep api | awk '{print $1}') -n $NAMESPACE
log_info "kubectl wait --for=condition=Ready pod/$(kubectl get pod -n $NAMESPACE | grep api | awk '{print $1}') -n $NAMESPACE"
kubectl wait --for=condition=Ready pod/$(kubectl get pod -n $NAMESPACE | grep api | awk '{print $1}') -n $NAMESPACE



