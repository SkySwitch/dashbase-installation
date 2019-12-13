#!/bin/bash

# Set default environment values.
PLATFORM="undefined"
NAMESPACE="dashbase"
RELEASE="dashbase"
VERSION="1.0.2"
VALUES_YAML='./values.yml'


# Preflight checks
echo "OS type running this script is $OSTYPE"

CMDS="kubectl tar curl"
for x in $CMDS
   do  command -v $x > /dev/null && continue || { echo "This script requires $x command and is not found."; exit 1; }
done

# Get PARAM from user input
if [[ "$OSTYPE" == "darwin"* ]]; then
    while [[ $# -gt 0 ]]; do
    PARAM=${1%%=*}
    [[ "$1" == *"="* ]] && VALUE=${1#*=} || VALUE=""
    #echo "Parsing ($1): $PARAM with ${VALUE:-no value}"
    shift 1

    case $PARAM in
      "--username" )
       if [ -n $VALUE  ]; then
         echo "$PARAM is empty"
        exit
       fi
        USERNAME=$VALUE
        ;;
      "--license" )
       if [ -n $VALUE  ]; then
         echo "$PARAM is empty"
        exit
       fi
        LICENSE=$VALUE
        ;;
      "--namespace" )
       if [ -n $VALUE  ]; then
         echo "$PARAM is empty"
        exit
       fi
        NAMESPACE=$VALUE
        ;;
      "--file" )
       if [ -n $VALUE  ]; then
         echo "$PARAM is empty"
        exit
       fi
        VALUES_YAML=$VALUE
        ;;
      "--name" )
       if [ -n $VALUE  ]; then
         echo "$PARAM is empty"
        exit
       fi
        RELEASE=$VALUE
        ;;
      "--version" )
       if [ -n $VALUE  ]; then
         echo "$PARAM is empty"
        exit
       fi
        VERSION=$VALUE
        ;;
      *)
        echo "Unknown parameter ($PARAM) with ${VALUE:-no value}"
        exit
        ;;
      esac
    done
    sed -i .bak "s|username:.*|username: $USERNAME|" $VALUES_YAML
    sed -i .bak "s|license:.*|license: $LICENSE|" $VALUES_YAML
elif [[ "$OSTYPE" == "linux-gnu" ]]; then
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
    sed -i "s|USERNAME|$USERNAME|" $VALUES_YAML
    sed -i "s|LICENSE|$LICENSE|" $VALUES_YAML
else
   echo "OSTYPE is not supported"
   exit
fi

# Check Running environment
RUNNING_RELEASE=$(helm ls  |grep install |awk '{print $1}')
RUNNING_NAMESPACE=$(helm ls |grep install | awk '{print $11}')
if [[ "$RUNNING_RELEASE" != "$RELEASE" ]]; then
    echo "Release named $RELEASE is not running, please check."
    exit
  if [ "$RUNNING_NAMESPACE" != "$NAMESPACE" ]; then
    echo "Namespace $NAMESPACE not match your release, please check."
    exit
  fi
fi


echo "helm repo add chartmuseum https://charts.dashbase.io"
helm repo add chartmuseum https://charts.dashbase.io
echo "helm upgrade $RELEASE chartmuseum/dashbase -f $VALUES_YAML --namespace $NAMESPACE -i  --version $VERSION"
helm upgrade $RELEASE chartmuseum/dashbase -f $VALUES_YAML --namespace $NAMESPACE -i  --version $VERSION &> /dev/null

echo "kubectl delete pod $(kubectl get pod -n install | grep api | awk '{print $1}') -n $NAMESPACE"
kubectl delete pod $(kubectl get pod -n install | grep api | awk '{print $1}') -n $NAMESPACE
echo "kubectl wait --for=condition=Ready pod/$(kubectl get pod -n $NAMESPACE | grep api | awk '{print $1}') -n $NAMESPACE"
kubectl wait --for=condition=Ready pod/$(kubectl get pod -n $NAMESPACE | grep api | awk '{print $1}') -n $NAMESPACE



