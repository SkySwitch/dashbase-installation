#!/bin/bash

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

check_commands() {
  CMDS="kubectl wget"
  for x in $CMDS
     do command -v "$x" > /dev/null && continue || { log_fatal "$x command not found."; }
  done
}

check_adminpod() {
  CHKADMINPOD=$(kubectl get po -n dashbase |grep -c admindash-0)
  if [ "$CHKADMINPOD" -eq "0" ]; then
    log_fatal "This script requires admin pod to run, and admindash-0 pod is not found"
  fi
}


VNUM=$(kubectl describe pod web-0 -n dashbase |grep "Image:" |awk '{ print $2}' | cut -d ":" -f2 |cut -d "." -f1)

# Download dashbase system table yaml files

download_table_yaml() {
   if [ "$VNUM" -ge 2 ]; then
      log_info "download dashbase system table yaml files for V2 setup"
      kubectl exec -it admindash-0 -n dashbase -- bash -c "wget -O /data/dashbase_system_log_table_v2.yaml https://github.com/dashbase/dashbase-installation/raw/master/deployment-tools/dashbase-admin/dashbase_setup_tarball/dashbase_system_log_table_v2.yaml"
   else
      log_info "download dashbase system table yaml files for V1 setup"
      kubectl exec -it admindash-0 -n dashbase -- bash -c "wget -O /data/dashbase_system_log_table_v1.yaml https://github.com/dashbase/dashbase-installation/raw/master/deployment-tools/dashbase-admin/dashbase_setup_tarball/dashbase_system_log_table_v1.yaml"
   fi
}

# update dashbase-values.yaml file

update_dashbase_values() {
  log_info "update dashbase-values.yaml file to enable dashbase system log collection"
  kubectl exec -it admindash-0 -n dashbase -- sed -i '/filebeat\:/!b;n;c\ \ enabled\: true' /data/dashbase-values.yaml
  if [ "$VNUM" -ge 2 ]; then
     kubectl exec -it admindash-0 -n dashbase -- sed -i '/V1_tables/ r /data/dashbase_system_log_table_v2.yaml' /data/dashbase-values.yaml
  else
     kubectl exec -it admindash-0 -n dashbase -- sed -i '/Dashbase_Logs/ r /data/dashbase_system_log_table_v1.yaml' /data/dashbase-values.yaml
  fi
}

check_helm() {
  # check helm
  # adding dashbase helm repo
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm repo add dashbase https://charts.dashbase.io"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm repo add stable https://kubernetes-charts.storage.googleapis.com"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm repo update"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm repo list"
}

# main process 

check_commands
check_adminpod
download_table_yaml
update_dashbase_values
check_helm

kubectl exec -it admindash-0 -n dashbase -- bash -c "helm upgrade dashbase dashbase/dashbase -f /data/dashbase-values.yaml --namespace dashbase --debug > /dev/null"
kubectl exec -it admindash-0 -n dashbase -- bash -c "helm ls -n dashbase"
