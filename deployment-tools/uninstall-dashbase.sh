#!/bin/bash
#
headline(){
  echo -e "###########################################################"
  echo -e "#####  Undo Dashbase Installation                     #####"
  echo -e "###########################################################"
}

remove_storageclass() {
    # delete storageclass
    if [ "$(kubectl get storageclass |grep -c dashbase)" -gt "0"  ]; then
       echo "dashbase storageclass exists"
       for STORECLASS in $(kubectl get storageclass |grep dashbase |awk '{print $1}' |tr "\n" " "); do
           echo "delete storageclass $STORECLASS"
           kubectl delete storageclass "$STORECLASS"
       done
    else
       echo "no dashbase storageclass is found"
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
          echo "cluster role binding $CRBIND exists"
          echo "delete cluster role  binding $CRBIND"
          kubectl delete clusterrolebinding $CRBIND
       else
          echo "cluster role binding $CRBIND is not found"
       fi
    done
}

remove_sa_tiller() {
      if [ "$(kubectl get sa -n kube-system |grep -c tiller)" -gt "0" ]; then
       echo "service account tiller exists"
       echo "delete service account tiller"
       kubectl delete sa tiller -n kube-system
    else
       echo "service account tiller is not found in kube-system namespace"
    fi
}

# main process below this line
headline

if [ "$(kubectl get namespace |grep -c dashbase)" -eq "1" ]; then
  echo "dashbase namespace exists"
  if [ "$(kubectl get po -n dashbase |grep -c admindash)" -eq "1" ]; then
     echo "admin pod exists"
     # check helm tiller
     if [ "$(kubectl get po -n kube-system |grep -c tiller-deploy)" -gt "0" ]; then
        echo "helm tiller is deployed in kube-system namespace"

        # check if nginx is deployed , if yes delete it; and timeout after 8 minutes
        while [ "$(kubectl exec -it admindash-0 -n dashbase -- helm ls |grep dashbase |grep -c nginx)" -eq "1" ] && [ $SECONDS -lt 480 ]; do
          echo "nginx-ingress controller is dedected"
          echo "removing ngnix-ingress controller"
          kubectl exec -it admindash-0 -n dashbase -- helm delete --purge nginx-ingress
        done
        # check if dashbase is deployed, if yes delete it; and timeout after 8 minutes
        while [ "$(kubectl exec -it admindash-0 -n dashbase -- helm ls |grep dashbase |grep -c -iv nginx)" -eq "1" ] && [ $SECONDS -lt 480 ]; do
          echo "dashbase components deployed"
          # remove dashbase
          echo "removing dashbase components"
          kubectl exec -it admindash-0 -n dashbase -- helm delete --purge dashbase
        done
        # check if presto is deployed if yes delete it; and timeout after 8 minutes
        # while [ "$(kubectl exec -it admindash-0 -n dashbase -- helm ls |grep -c presto)" -eq "1" ] && [ $SECONDS -lt 480 ]; do
        #  echo "presto components deployed"
        #  echo "removing presto components"
        #  kubectl exec -it admindash-0 -n dashbase -- helm delete --purge presto
        # done
     else
        echo "helm tiller is not found in K8s cluster"
     fi
     
     # delete admin pod
     echo "delete admin pod dashadmin-0"
     kubectl delete sts/admindash -n dashbase

    # delete dashbase persistent volume claim
    if [ "$(kubectl get  pvc -n dashbase |grep -c -iv CAPACITY)" -gt "0" ]; then
       echo "dashbase PVC exists"
       for PVC in $(kubectl get pvc -n dashbase |tail -n +2 |awk '{print $1}' |tr "\n" " "); do
           echo "delete pvc $PVC"
           kubectl delete pvc  "$PVC" -n dashbase
       done
    else
       echo "no dashbase PVC is found in dashbase namespace"
    fi
    # delete dashbase secrets
    if [ "$(kubectl get secrets -n dashbase |grep -E -c 'dashbase-key|dashbase-cert')" -gt "0" ]; then
       echo "dashbase secrets exists"
       for DSECRETS in $(kubectl get secrets -n dashbase |grep -E 'dashbase-cert|dashbase-key' |awk '{print $1}' |tr "\n" " "); do
           echo "delete secrets $DSECRETS"
           kubectl delete secrets "$DSECRETS" -n dashbase
       done
    else
       echo "no dashbase secrets is found in dashbase namespace"
    fi
    # delete presto secrets
    if [ "$(kubectl get secrets -n dashbase |grep -E -c 'presto-key|presto-cert')" -gt "0" ]; then
       echo "presto secrets exists"
       for PSECRETS in $(kubectl get secrets -n dashbase |grep -E 'presto-cert|presto-key' |awk '{print $1}' |tr "\n" " "); do
           echo "delete secrets $PSECRETS"
           kubectl delete secrets "$PSECRETS" -n dashbase
       done
    else
       echo "no presto secrets is found in dashbase namespace"
    fi

    # delete storageclass
    remove_storageclass
    #  delete helm tiller
    remove_tiller
    # delete clusterrolebindings
    remove_clusterrolebindings
    # delete sa dashadmin account
    if [ "$(kubectl get sa -n dashbase |grep -c dashadmin)" -gt "0" ]; then
       echo "service account dashadmin exists"
       echo "delete service account dashadmin"
       kubectl delete sa dashadmin -n dashbase
    else
       echo "service account dashadmin is not found in dashbase namespace"
    fi
    # delete sa tiller account
    remove_sa_tiller
    # delete namespace
    kubectl delete namespace dashbase
  fi

else
  echo "dashbase namespace is not found"
  remove_storageclass
  remove_tiller
  remove_clusterrolebindings
  remove_sa_tiller
fi


