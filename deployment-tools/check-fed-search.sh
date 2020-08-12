#!/bin/bash

function log_info() {
  echo -e "INFO *** $*"
}

function log_warning() {
  echo -e "WARN *** $*"
}

function log_error() {
  echo -e "ERROR *** $*"
}

function log_fatal() {
  echo -e "FATAL *** $*"
  exit 1
}

CMDS="kubectl jq"
for x in $CMDS; do
  command -v "$x" >/dev/null && continue || {
    log_fatal "This script requires $x command and is not found."
  }
done

APIHOST=$(kubectl get po -n dashbase | grep api | awk '{print $1}')
#DNSHOST=$(kubectl get po -n kube-system | grep -E 'kube-dns|coredns' | awk '{print $1}' | tr '\n' ' ')
DNSCM=$(kubectl get cm -n kube-system |grep -E 'kube-dns|coredns' |sort |uniq |awk '{print $1}')
#STUBDOMAIN=$(kubectl get cm $DNSCM -n kube-system -o=jsonpath='{.data.stubDomains}' | jq |grep ":" |sed -e 's/\"//g; s/\[//g; s/\://g' |awk '{$1=$1;print}' | tr '\n' ' ' |awk '{$1=$1;print}')
DOWNAPI=$(kubectl describe po $APIHOST -n dashbase |grep DOWNSTREAM_APIS |awk '{print $2}' |sed 's/https\?:\/\///g; s/\://g; s/9876//g; s/\,/\ /')
#INTTOKEN=changeme

# main process below this line
log_info "upstream api pod is $APIHOST"
log_info "stud domains and its corresponding dns servers are followings"
kubectl get cm $DNSCM -n kube-system -o=jsonpath='{.data.stubDomains}' | jq

rm -rf /tmp/apipingtest

for X in $DOWNAPI; do
  log_info " ping to $X"
  kubectl exec -it $APIHOST -n dashbase -- ping $X -i1 -c1 |grep "%" | tee -a /tmp/apipingtest
  IPA=$(kubectl exec -it $APIHOST -n dashbase -- ping $X -i1 -c1  |grep PING |awk '{ print $3}' |sed -e 's|(||; s|)||')
  if [ "$(kubectl exec -it $APIHOST -n dashbase -- ping $X -i1 -c1 |grep "%" |awk '{print $6}')" == "0%" ]; then
     log_info "ping test to  $X with internal IP address $IPA ---- PASS"
     # uncomment the following lines after update INTTOKEN env var
     #DWNTABLE=$(kubectl exec -it $APIHOST -n dashbase -- curl -k "https://$X:9876/v1/cluster/tables" -v  -H 'Authorization: Bearer $INTTOKEN' |tail -1)
     #log_info "From downstream api $X , the tables are $DWNTABLE"
  else
     log_error "ping test to $X is FAIL"
     log_info "Please check the kube-dns configmap $DNSCM"
     log_info "Please check the downstream api po $X with internal IP address $IPA"
     log_info "Please check the network route and network security policy on both sides"
  fi
done

