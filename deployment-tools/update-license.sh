#!/bin/bash

USERNAME="undefined"
LICENSE="undefined"

function log_info() {
  echo -e "INFO *** $*"
}

function log_warning() {
  echo -e "WARN *** $*"
}

function log_fatal() {
  echo -e "FATAL *** $*"
  rm -rf ./dashbase-license.txt
  exit 1
}

function fail_if_empty() {
  [[ -z "$2" ]] && log_fatal "Parameter $1 must have a value."
  return 0
}

function run_catch() {
if [[ $? = 0 ]]; then
  log_info "SUCCESS: $*"
else
  log_fatal "FAILURE: $*"
fi
}

while [[ $# -gt 0 ]]; do
  PARAM=${1%%=*}
  [[ "$1" == *"="* ]] && VALUE=${1#*=} || VALUE=""
  log_info "Parsing ($1)"
  shift 1

  case $PARAM in
  --username)
    fail_if_empty "$PARAM" "$VALUE"
    USERNAME=$VALUE
    ;;
  --license)
    fail_if_empty "$PARAM" "$VALUE"
    LICENSE=$VALUE
    ;;
  *)
    log_warning "Unknown parameter ($PARAM) with ${VALUE:-no value}"
    ;;
  esac
done

# Create dashbase-license.txt
  if [[ "$USERNAME" == "undefined" || "$LICENSE" == "undefined" ]]; then
    log_fatal "License information is not correct."
  else
    log_info "Loading dashbase-license username and license."
    echo "username: \"$USERNAME\"" > dashbase-license.txt
    echo "license: \"$LICENSE\"" >> dashbase-license.txt
  fi

# Update dashbase license information
log_info "Update default dashbase-values.yaml file with entered license information."
kubectl cp dashbase-license.txt dashbase/admindash-0:/dashbase/

log_info "Cleaning old license of dashbase-values.yaml "
kubectl exec -it admindash-0 -n dashbase -- bash -c "sed -i '/^username:/d;/^license:/d' /data/dashbase-values.yaml"
log_info "Update license into dashbase-values.yaml"
kubectl exec -it admindash-0 -n dashbase -- bash -c "cat dashbase-license.txt >> /data/dashbase-values.yaml"

# Check chart version
chart_version=$(kubectl exec -it admindash-0 -n dashbase -- bash -c "helm ls '^dashbase$' |grep 'dashbase' |  awk '{print \$9}' |  cut -c 10-  ")

if [[ $chart_version == \>* ]]; then
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm upgrade dashbase dashbase/dashbase -f /data/dashbase-values.yaml --home /root/.helm --namespace dashbase --devel &> /dev/null"
  run_catch "helm upgrade dashbase dashbase/dashbase -f /data/dashbase-values.yaml --home /root/.helm --namespace dashbase --devel"
else
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm upgrade dashbase dashbase/dashbase -f /data/dashbase-values.yaml --home /root/.helm --namespace dashbase --version $chart_version &> /dev/null"
  run_catch "helm upgrade dashbase dashbase/dashbase -f /data/dashbase-values.yaml --namespace dashbase --version $chart_version"
fi

# Update dashbase license information
kubectl delete pod "$(kubectl get pod -n dashbase | grep api | awk '{print $1}')" -n dashbase
run_catch "kubectl delete pod $(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase"

kubectl wait --timeout=180s --for=condition=available deployment/api -n dashbase
run_catch "kubectl wait --timeout=180s --for=condition=available deployment/api -n dashbase"

if [[ $? -eq 0 ]]; then
  log_info "License update successful, enjoy your dashbase."
  rm -rf ./dashbase-license.txt
else
  log_fatal "License update failed."
fi





