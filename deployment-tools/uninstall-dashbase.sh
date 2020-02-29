#!/bin/bash

CMDS="curl kubectl"

headline(){
  echo -e "###########################################################"
  echo -e "#####  Undo Dashbase Installation                     #####"
  echo -e "#####  this script requires kubectl commands          #####"
  echo -e "###########################################################"
}

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
  for x in $CMDS
     do command -v "$x" > /dev/null && continue || { log_fatal "$x command not found."; }
  done
}

remove_storageclass() {
    # delete storageclass
    if [ "$(kubectl get storageclass |grep -c dashbase)" -gt "0"  ]; then
       log_info "dashbase storageclass exists"
       for STORECLASS in $(kubectl get storageclass |grep dashbase |awk '{print $1}' |tr "\n" " "); do
           log_info "delete storageclass $STORECLASS"
           kubectl delete storageclass "$STORECLASS"
       done
    else
       log_info "no dashbase storageclass is found"
    fi
}

remove_tiller() {
    #  delete helm tiller
    if [ "$(kubectl get po -n kube-system |grep -c tiller-deploy)" -gt "0" ]; then
       echo "helm tiller exists in K8s cluster"
       echo "delete tiller pod"
       kubectl delete deployment tiller-deploy -n kube-system
    else
       echo "no tiller pod is found in K8s cluster"
    fi
}

remove_clusterrolebindings() {
    # delete clusterrolebindings
    for CRBIND in admin-user-binding tiller ; do
       if [ "$(kubectl get clusterrolebindings |grep -c $CRBIND)" -gt "0" ]; then
          log_info "cluster role binding $CRBIND exists"
          log_info "delete cluster role  binding $CRBIND"
          kubectl delete clusterrolebinding $CRBIND
       else
          log_info "cluster role binding $CRBIND is not found"
       fi
    done
}

remove_sa_tiller() {
      if [ "$(kubectl get sa -n kube-system |grep -c tiller)" -gt "0" ]; then
       log_info "service account tiller exists"
       log_info "delete service account tiller"
       kubectl delete sa tiller -n kube-system
    else
       log_info "service account tiller is not found in kube-system namespace"
    fi
}

remove_ingress_via_admindash() {
  # check if nginx is deployed , if yes delete it; and timeout after 8 minutes
  while [ "$(kubectl exec -it admindash-0 -n dashbase -- helm ls |grep dashbase |grep -c nginx)" -eq "1" ] && [ $SECONDS -lt 480 ]; do
    log_info "nginx-ingress controller is dedected"
    log_info "removing ngnix-ingress controller"
    kubectl exec -it admindash-0 -n dashbase -- helm delete --purge nginx-ingress
  done
}

remove_dashbase_via_admindash() {
  # check if dashbase is deployed, if yes delete it; and timeout after 8 minutes
  while [ "$(kubectl exec -it admindash-0 -n dashbase -- helm ls |grep dashbase |grep -c -iv nginx)" -eq "1" ] && [ $SECONDS -lt 480 ]; do
    log_info "dashbase components deployed via helm"
    # remove dashbase
    log_info "removing dashbase components via helm in admindash pod"
    kubectl exec -it admindash-0 -n dashbase -- helm delete --purge dashbase
  done
}

remove_ingress_via_admindash_helm3() {
  # check if nginx is deployed , if yes delete it; and timeout after 8 minutes
  while [ "$(kubectl exec -it admindash-0 -n dashbase -- helm ls -n dashbase |grep dashbase |grep -c nginx)" -eq "1" ] && [ $SECONDS -lt 480 ]; do
    log_info "nginx-ingress controller is dedected"
    log_info "removing ngnix-ingress controller"
    kubectl exec -it admindash-0 -n dashbase -- helm delete nginx-ingress -n dashbase
  done
}

remove_dashbase_via_admindash_helm3() {
  # check if dashbase is deployed, if yes delete it; and timeout after 8 minutes
  while [ "$(kubectl exec -it admindash-0 -n dashbase -- helm ls -n dashbase |grep dashbase |grep -c -iv nginx)" -eq "1" ] && [ $SECONDS -lt 480 ]; do
    log_info "dashbase components deployed via helm"
    # remove dashbase
    log_info "removing dashbase components via helm in admindash pod"
    kubectl exec -it admindash-0 -n dashbase -- helm delete dashbase -n dashbase
  done
}


remove_ingress_via_helm() {
  # check if nginx is deployed , if yes delete it; and timeout after 8 minutes
  while [ "$(helm ls |grep dashbase |grep -c nginx)" -eq "1" ] && [ $SECONDS -lt 480 ]; do
    log_info "nginx-ingress controller is dedected"
    log_info "removing ngnix-ingress controller"
    helm delete --purge nginx-ingress
  done
}

remove_dashbase_via_helm() {
  # check if dashbase is deployed, if yes delete it; and timeout after 8 minutes
  while [ "$(helm ls |grep dashbase |grep -c -iv nginx)" -eq "1" ] && [ $SECONDS -lt 480 ]; do
    log_info "dashbase components deployed via helm"
    # remove dashbase
    log_info "removing dashbase components via helm in admindash pod"
    helm delete --purge dashbase
  done
}

remove_ingress_via_helm_3() {
  # check if nginx is deployed , if yes delete it; and timeout after 8 minutes
  while [ "$(helm ls -n dashbase |grep -c nginx)" -eq "1" ] && [ $SECONDS -lt 480 ]; do
    log_info "nginx-ingress controller is dedected"
    log_info "removing ngnix-ingress controller"
    helm delete nginx-ingress -n dashbase
  done
}

remove_dashbase_via_helm_3() {
  # check if dashbase is deployed, if yes delete it; and timeout after 8 minutes
  while [ "$(helm ls -n dashbase |grep dashbase |grep -c -iv nginx)" -eq "1" ] && [ $SECONDS -lt 480 ]; do
    log_info "dashbase components deployed via helm"
    # remove dashbase
    log_info "removing dashbase components via helm in admindash pod"
    helm delete dashbase -n dashbase
  done
}

remove_release_via_helm() {
  if [ "$( helm version --client |grep -c "v3." )" -eq "1" ]; then
    log_info "helm3 is detected"
    if [ "$(helm ls -n dashbase |grep -E -- 'dashbase|ingress')" ]; then
      log_info "Either dashbase or ingress release exists on dashbase namespace"
      remove_ingress_via_helm_3
      remove_dashbase_via_helm_3
    fi
  elif [ "$( helm version --client |grep -c "v2." )" -eq "1" ]; then
    log_info "helm2 is detected"
    if [ "$(helm ls |grep -E -- 'dashbase|ingress')" ]; then
      log_info "Either dashbase or ingress release exists on dashbase namespace"
      remove_ingress_via_helm
      remove_dashbase_via_helm
    fi
  else
    log_fatal "the helm version is neither 2 or 3"
  fi
}


delete_dashbase_pvc() {
  # delete dashbase persistent volume claim
  if [ "$(kubectl get  pvc -n dashbase |grep -c -iv CAPACITY)" -gt "0" ]; then
    log_info "dashbase PVC exists"
    for PVC in $(kubectl get pvc -n dashbase |tail -n +2 |awk '{print $1}' |tr "\n" " "); do
        log_info "delete pvc $PVC"
        kubectl delete pvc  "$PVC" -n dashbase
    done
  else
       log_info "no dashbase PVC is found in dashbase namespace"
  fi
}

delete_dashbase_secrets() {
  # delete dashbase secrets
  if [ "$(kubectl get secrets -n dashbase |grep -E -c 'dashbase-key|dashbase-cert')" -gt "0" ]; then
    log_info "dashbase secrets exists"
    for DSECRETS in $(kubectl get secrets -n dashbase |grep -E 'dashbase-cert|dashbase-key' |awk '{print $1}' |tr "\n" " "); do
      log_info "delete secrets $DSECRETS"
      kubectl delete secrets "$DSECRETS" -n dashbase
    done
  else
    log_info "no dashbase secrets is found in dashbase namespace"
  fi
  # delete presto secrets
  if [ "$(kubectl get secrets -n dashbase |grep -E -c 'presto-key|presto-cert')" -gt "0" ]; then
    log_info "presto secrets exists"
    for PSECRETS in $(kubectl get secrets -n dashbase |grep -E 'presto-cert|presto-key' |awk '{print $1}' |tr "\n" " "); do
      log_info "delete secrets $PSECRETS"
      kubectl delete secrets "$PSECRETS" -n dashbase
    done
  else
    log_info "no presto secrets is found in dashbase namespace"
  fi
}

remove_sa_dashadmin() {
  # delete sa dashadmin account
  if [ "$(kubectl get sa -n dashbase |grep -c dashadmin)" -gt "0" ]; then
    log_info "service account dashadmin exists"
    log_info "delete service account dashadmin"
    kubectl delete sa dashadmin -n dashbase
  else
    log_info "service account dashadmin is not found in dashbase namespace"
  fi
}

remove_combo() {
    # delete pvc
    delete_dashbase_pvc
    # delete secrets
    delete_dashbase_secrets
    # delete storageclass
    remove_storageclass
    #  delete helm tiller
    remove_tiller
    # delete clusterrolebindings
    remove_clusterrolebindings
    # delete sa dashadmin account
    remove_sa_dashadmin
    # delete sa tiller account
    remove_sa_tiller
    # delete namespace
    kubectl delete namespace dashbase
}

# main process below this line
headline

# check dashbase namespace has or not
if [ "$(kubectl get namespace |grep -c dashbase)" -eq "1" ]; then
  log_info "dashbase namespace exists"

  # check helm tiller deploy or not
  if [ "$(kubectl get po -n kube-system |grep -c tiller-deploy)" -gt "0" ]; then
     log_info "helm tiller is deployed in kube-system namespace"

     # check has admindash pod or not
     if [ "$(kubectl get po -n dashbase |grep -c admindash)" -eq "1" ]; then
        log_info "admin pod exists"
        log_info "checking and removing any resources in dashbase namespace from admindash helm"
        # check admin pod has helm 2 or 3
        if [ "$(kubectl exec -it admindash-0 -n dashbase -- helm version --client |grep -c "v3.")" -eq "1" ]; then
          remove_ingress_via_admindash_helm3
          remove_dashbase_via_admindash_helm3
        else
          remove_ingress_via_admindash
          remove_dashbase_via_admindash
        fi

        sleep 10
        # delete admin pod
        log_info "delete admin pod dashadmin-0"
        kubectl delete sts/admindash -n dashbase
        remove_combo

     # check if helm command exists in local workstation
     elif [ "$(command -v helm)" ]; then
        log_info "helm command exists"
        log_info "checking and removing any resources in dashbase namespace from helm configured locally"
        log_info "check helm version 2 or 3"
        remove_release_via_helm
        sleep 10
        remove_combo
     else
        log_fatal "helm tiller is deployed but either no admindash pod or local helm command to check any resource deployed via helm"
    fi
  else
    log_info "No helm tiller deployed to this K8s cluster"
    log_info "check helm commands from local workstation"
    if [ "$(command -v helm)" ]; then
        log_info "helm command exists"
        log_info "checking and removing any resources in dashbase namespace from helm configured locally"
        log_info "check helm version 2 or 3"
        remove_release_via_helm
        sleep 10
    else
        log_warning "No helm found in local workstation"
    fi
     # check if amdindash pod exists but no helm tiller deployed
     # this condition could be arise from a failed previous dashbase installation
    if [ "$(kubectl get po -n dashbase |grep -c admindash)" -eq "1" ]; then
         # delete admin pod
        log_info "delete admin pod dashadmin-0"
        kubectl delete sts/admindash -n dashbase
    fi
    sleep 10
    remove_combo
  fi
else
  log_info "No dashbase namespace is found in this K8s cluster"
  remove_storageclass
  remove_tiller
  remove_clusterrolebindings
  remove_sa_tiller
fi

