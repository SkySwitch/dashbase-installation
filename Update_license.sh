#!/bin/bash

# Set default environment values.
DEFAULT_VALUES_YAML='./dashbase_values.yaml'

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
      "--values_file" )
        fail_if_empty "$PARAM" "$VALUE"
        VALUES_YAML=$VALUE
        ;;
        *)
        echo "Unknown parameter ($PARAM) with ${VALUE:-no value}"
        ;;
      esac
    done

# Update values.yaml file
if [[ $(cat $VALUES_YAML |grep -e "^username:") == "" ]]; then
  log_info "No username specified in values YAML file, creating"
  echo -e 'username:' >> $VALUES_YAML
fi
if [[ $(cat $VALUES_YAML |grep -e "^license:") == "" ]]; then
  log_info "No license specified in values YAML file, creating"
  echo -e 'license:' >> $VALUES_YAML
fi
  log_info "Updating license in values.yaml"
  sed -i "s|username:.*|username: $USERNAME|" $VALUES_YAML
  sed -i "s|license:.*|license: $LICENSE|" $VALUES_YAML

log_info "helm repo add chartmuseum https://charts.dashbase.io"
helm repo add chartmuseum https://charts.dashbase.io
log_info "helm upgrade dashbase chartmuseum/dashbase -f $VALUES_YAML --namespace dashbase -i  --version $VERSION"
helm upgrade dashbase chartmuseum/dashbase -f $VALUES_YAML --namespace dashbase -i  --version $VERSION &> /dev/null

log_info "kubectl delete pod $(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase"
kubectl delete pod $(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase
log_info "kubectl wait --for=condition=Ready pod/$(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase"
kubectl wait --for=condition=Ready pod/$(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase



