#!/bin/bash

USERNAME="undefined"
LICENSE="undefined"
VALUEFILE="dashbase-values.yaml"
VERSION="undefined"
CHARTVERSION="undefined"
DOCKERHUB_REGISTRY="https://registry.hub.docker.com/v2/repositories/dashbase/api/tags/"
CURRENTVERSION=$(kubectl exec -it admindash-0 -n dashbase -- kubectl get pods/web-0 -n dashbase  -o jsonpath='{.spec.containers[*].image}' |cut -d":" -f2)

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

echo "$@" >setup_arguments
echo "$#" >no_arguments

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
  #CURRENTVERSION=$(kubectl exec -it admindash-0 -n dashbase -- kubectl get pods/web-0 -n dashbase  -o jsonpath='{.spec.containers[*].image}' |cut -d":" -f2)
  if [ "$VERSION" == "undefined" ]; then
    log_info "No input dashbase version, no change in dashbase version"
    VERSION=$CURRENTVERSION
    # update dashbase value yaml file for version string
    # kubectl exec -it admindash-0 -n dashbase -- bash -c "sed -i '/^dashbase_version:/d' /data/dashbase-values.yaml"
    # kubectl exec -it admindash-0 -n dashbase -- sed -i "1 i\dashbase_version: $VERSION" /data/dashbase-values.yaml
  else
    log_info "Dashbase version entered is $VERSION"
    # checking input version is valid or not
    log_info "Checking the entered version $VERSION is valid or not"
    if [ "$(curl --silent -k "$DOCKERHUB_REGISTRY$VERSION" |tr -s ',' '\n' |grep -c digest)" -eq 1 ]; then
      log_info "Entered dashbase version $VERSION is valid"
    else
      log_fatal "Entered dashbase version $VERSION is invalid"
    fi
    # make sure input version is newer than current version
    CURRENTVERSION_TIME=$(curl --silent -k "$DOCKERHUB_REGISTRY$CURRENTVERSION" |tr -s ',' '\n' |grep last_updated |cut -d":" -f2-4 |sed -e 's/\"//g' |tr -d 'Z\}')
    NEWVERSION_TIME=$(curl --silent -k "$DOCKERHUB_REGISTRY$VERSION" |tr -s ',' '\n' |grep last_updated |cut -d":" -f2-4 |sed -e 's/\"//g' |tr -d 'Z\}')
    echo "Current dashbase version is created on $CURRENTVERSION_TIME"
    echo "Current dashbase version is created on $NEWVERSION_TIME"
    if [[ $(kubectl exec -it admindash-0 -n dashbase -- date -d "$CURRENTVERSION_TIME" "+%s") < $(kubectl exec -it admindash-0 -n dashbase -- date -d "$NEWVERSION_TIME" "+%s")  ]]; then
      log_info "The entered version $VERSION is newer than current version $CURRENTVERSION"
    else
      log_fatal "The entered version $VERSION is older than current version $CURRENTVERSION , and please manually downgrade dashbase installation"
    fi
    # update dashbase value yaml file for version string
    kubectl exec -it admindash-0 -n dashbase -- bash -c "sed -i '/^dashbase_version:/d' /data/dashbase-values.yaml"
    kubectl exec -it admindash-0 -n dashbase -- sed -i "1 i\dashbase_version: $VERSION" /data/dashbase-values.yaml
  fi
}

# Check chart version
# if chart version is not provided, then will use whatever previously is used
check_chart_version() {
chart_version=$(kubectl exec -it admindash-0 -n dashbase -- bash -c "helm ls '^dashbase$' |grep 'dashbase' |  awk '{print \$9}' |  cut -c 10-  ")

if [[ "$CHARTVERSION" == "undefined" ]] && [[ "$VERSION" == "undefined" ]]; then
  echo "Both dashbase version and chart version are not provided"
  echo "checking previous chart version is used in the deployment"
  if [[ $chart_version == \>* ]]; then
    echo "current chart version is using latest devel, and will continue using devel chart version"
    chartver="--devel"
  else
    echo "current chart version is $chart_version"
    echo "will use current chart version $chart_version"
    chartver="--version $chart_version"
  fi
elif [[ "$CHARTVERSION" == "undefined" ]] && [[ "$VERSION" != "undefined"  ]]; then
  echo "Dashbase version is provided and chart version is not provided"
  echo "Both dashbase version and chart version will be in version $VERSION"
  chartver="--version $VERSION"
elif [[ "$CHARTVERSION" == "devel" ]]; then
  echo "Entered chart version is latest development version"
  chartver="--devel"
elif [[ "$CHARTVERSION" == "current" ]]; then
  echo "Entered chart version is using current version $chart_version"
  chartver="--version $chart_version"
elif [[ "$CHARTVERSION" != "undefined" ]]; then
  echo "Entered chart version is $CHARTVERSION"
  chartver="--version $CHARTVERSION"
fi
}

# main process below this line

#CURRENTVERSION=$(kubectl exec -it admindash-0 -n dashbase -- kubectl get pods/web-0 -n dashbase  -o jsonpath='{.spec.containers[*].image}' |cut -d":" -f2)
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
if [[ "$LICENSE" != "undefined" || "$USERNAME" != "undefined" ]] && [[ "$VERSION" == "$CURRENTVERSION" ]]; then

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
