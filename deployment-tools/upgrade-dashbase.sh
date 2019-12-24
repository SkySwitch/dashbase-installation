#!/bin/bash

USERNAME="undefined"
LICENSE="undefined"
VALUEFILE="dashbase-values.yaml"
VERSION="undefined"
CHARTVERSION="undefined"

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
  if [[ $? == 0 ]]; then
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
  --version)
    fail_if_empty "$PARAM" "$VALUE"
    VERSION=$VALUE
    ;;
  --chartversion)
    fail_if_empty "$PARAM" "$VALUE"
    CHARTVERSION=$VALUE
    ;;
  *)
    log_warning "Unknown parameter ($PARAM) with ${VALUE:-no value}"
    ;;
  esac
done

backup_values_yaml() {
  HELM_VERSION=$(kubectl exec -it admindash-0 -n dashbase -- helm ls --home /root/.helm |grep dashbase |awk '{print $2}')
  kubectl exec -it admindash-0 -n dashbase -- bash -c "mkdir -p /data/backup_values_yaml"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "cp /data/dashbase-values.yaml /data/backup_values_yaml/dashbase-values_$(date +%d-%m-%Y_%H-%M-%S)_$HELM_VERSION.yaml"
}


update_license() {
  # check and udpate license information
  if [[ "$USERNAME" == "undefined" && "$LICENSE" == "undefined" ]]; then
    log_info "No License information is entered."
  elif [[ "$USERNAME" == "undefined" && "$LICENSE" != "undefined" ]]; then
    log_fatal "missing username"
  elif [[ "$USERNAME" != "undefined" && "$LICENSE" == "undefined" ]]; then
    log_fatal "missing license string"
  else
    log_info "Loading dashbase-license username and license."
    echo "username: \"$USERNAME\"" >dashbase-license.txt
    echo "license: \"$LICENSE\"" >>dashbase-license.txt
    # Update dashbase license information
    log_info "Update default dashbase-values.yaml file with entered license information."
    kubectl cp dashbase-license.txt dashbase/admindash-0:/dashbase/
    log_info "Cleaning old license of dashbase-values.yaml "
    kubectl exec -it admindash-0 -n dashbase -- bash -c "sed -i '/^username:/d;/^license:/d' /data/dashbase-values.yaml"
    log_info "Update license into dashbase-values.yaml"
    kubectl exec -it admindash-0 -n dashbase -- bash -c "cat dashbase-license.txt >> /data/dashbase-values.yaml"
  fi
}

check_version() {
  if [ "$VERSION" == "undefined" ]; then
    log_info "No input dashbase version, use default nightly"
    VERSION="nightly"
    # update dashbase value yaml file for version string
    kubectl exec -it admindash-0 -n dashbase -- bash -c "sed -i '/^dashbase_version:/d' /data/dashbase-values.yaml"
    kubectl exec -it admindash-0 -n dashbase -- sed -i "1 i\dashbase_version: nightly" /data/dashbase-values.yaml
  else
    log_info "Dashbase version entered is $VERSION"
    # update dashbase value yaml file for version string
    kubectl exec -it admindash-0 -n dashbase -- bash -c "sed -i '/^dashbase_version:/d' /data/dashbase-values.yaml"
    kubectl exec -it admindash-0 -n dashbase -- sed -i "1 i\dashbase_version: $VERSION" /data/dashbase-values.yaml
  fi
}

# Check chart version
# if chart version is not provided, then will use whatever previously is used
check_chart_version() {
if [[ "$CHARTVERSION" == "undefined" ]]; then

  echo "checking previous chart version is used in the deployment"
  chart_version=$(kubectl exec -it admindash-0 -n dashbase -- bash -c "helm ls '^dashbase$' |grep 'dashbase' |  awk '{print \$9}' |  cut -c 10-  ")

  if [[ $chart_version == \>* ]]; then
    echo "current chart version is using latest devel, and will continue using devel chart version"
    chartver="--devel"
  else
    echo "current chart version is $chart_version"
    echo "will use default chart version in repo"
    chartver=""
  fi
else
  echo "Entered chart version is $CHARTVERSION"
  chartver="--version $CHARTVERSION"
fi
}

# main process below this line

backup_values_yaml

# check entered dashbase value yaml file
# if using custom value yaml file will skip all other configurations

if [ "$VALUEFILE" == "dashbase-values.yaml" ]; then
  log_info "dashbase value yaml file is using default /data/dashbase-values.yaml file"
  update_license
  check_version
  check_chart_version
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm upgrade dashbase dashbase/dashbase -f /data/dashbase-values.yaml --home /root/.helm --namespace dashbase $chartver &> /dev/null"
  run_catch "helm upgrade dashbase dashbase/dashbase -f /data/dashbase-values.yaml --home /root/.helm --namespace dashbase $chartver"
else
  log_info "using custom dashbase value file $VALUEFILE"
  kubectl cp "$VALUEFILE" dashbase/admindash-0:/data/
  DASHVALUEFILE=$(echo $VALUEFILE | rev | cut -d"/" -f1 | rev)
  check_chart_version
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm upgrade dashbase dashbase/dashbase -f /data/$DASHVALUEFILE --namespace dashbase --home /root/.helm $chartver > /dev/null"
  run_catch "helm upgrade dashbase dashbase/dashbase -f /data/$DASHVALUEFILE --namespace dashbase --home /root/.helm $chartver"
fi


# Force restart api pod when upgrade license only and no dashbase version change
if [[ "$LICENSE" != "undefined" || "$USERNAME" != "undefined" ]] && [[ "$VERSION" == "nightly" ]]; then

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
fi
