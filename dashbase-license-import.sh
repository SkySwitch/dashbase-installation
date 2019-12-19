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

# Check that the dashbase-license.txt is valid
if [[ $(cat dashbase-license.txt |grep -e "^username:") == "" ]]; then
  log_fatal "No username specified in dashbase-license.txt, please check again! "
  exit 1
fi
if [[ $(cat dashbase-license.txt |grep -e "^license:") == "" ]]; then
  log_fatal "No license specified in dashbase-license.txt, please check again! "
  exit 1
fi

 # update dashbase license information
log_info "update default dashbase-values.yaml file with entered license information"
kubectl cp dashbase-license.txt dashbase/admindash-0:/dashbase/
kubectl exec -it admindash-0 -n dashbase -- bash -c "sed '/^username:/d;/^license:/d' dashbase_values.yaml > dashbase_values.yaml"
kubectl exec -it admindash-0 -n dashbase -- bash -c "cat dashbase-license.txt >> dashbase-values.yaml"


log_info "helm upgrade dashbase chartmuseum/dashbase -f $VALUES_YAML --namespace dashbase -i  --version $VERSION"
kubectl exec -it admindash-0 -n dashbase -- bash -c "helm upgrade dashbase dashbase/dashbase -f dashbase_values.yaml --namespace dashbase "

log_info "kubectl delete pod $(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase"
kubectl delete pod $(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase
log_info "kubectl wait --for=condition=Ready pod/$(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase"
kubectl wait --for=condition=Ready pod/$(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase



