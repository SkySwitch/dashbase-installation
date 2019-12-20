#!/bin/bash

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
grep -e "^username: \".*\""  dashbase-license.txt > /dev/null  &&  grep -e "^license: \".*\"" dashbase-license.txt > /dev/null
if [ $? -ne 0 ]; then
  log_fatal "Username or license format is invaild, please check it ! "
else
  log_info "dashbase-license.txt is valid, passed."
fi

#Update dashbase license information
log_info "update default dashbase-values.yaml file with entered license information"
kubectl cp dashbase-license.txt dashbase/admindash-0:/dashbase/
kubectl exec -it admindash-0 -n dashbase -- bash -c "sed '/^username:/d;/^license:/d' dashbase_values.yaml > dashbase_values.yaml"
kubectl exec -it admindash-0 -n dashbase -- bash -c "cat dashbase-license.txt >> dashbase-values.yaml"


log_info "helm upgrade dashbase chartmuseum/dashbase -f dashbase_values.yaml --namespace dashbase "
kubectl exec -it admindash-0 -n dashbase -- bash -c "helm upgrade dashbase dashbase/dashbase -f dashbase_values.yaml --namespace dashbase "

log_info "kubectl delete pod $(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase"
kubectl delete pod $(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase
log_info "kubectl wait --for=condition=Ready pod/$(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase"
kubectl wait --timeout=-1 --for=condition=Ready pod/$(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase



