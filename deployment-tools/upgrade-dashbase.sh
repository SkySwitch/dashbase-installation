#!/bin/bash

USERNAME="undefined"
LICENSE="undefined"
VALUEFILE="dashbase-values.yaml"
VERSION="undefined"
CHARTVERSION="undefined"
DOCKERHUB_REGISTRY="https://registry.hub.docker.com/v2/repositories/dashbase/api/tags/"
CURRENTVERSION=$(kubectl exec -it admindash-0 -n dashbase -- kubectl get pods/web-0 -n dashbase  -o jsonpath='{.spec.containers[*].image}' |cut -d":" -f2)
OLDREVISION=$(kubectl exec -it admindash-0 -n dashbase -- helm ls -n dashbase |sed -e 1d |grep -iv ingress |awk '{print $3}')

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

function run_check() {
  if [[ "$NEWREVISION" != "$OLDREVISION" ]] && [[ "$USTATUS" == "deployed" ]]; then
    log_info "SUCCESS: $*"
    log_info "SUCCESS: dashbase is upgraded"
  else
    log_fatal "FAILURE: $*"
  fi
}

function run_catch() {
  if [[ $? == 0 ]]; then
    log_info "SUCCESS: $*"
  else
    log_fatal "FAILURE: $*"
  fi
}

echo "$@" > /tmp/setup_arguments
echo "$#" > /tmp/no_arguments

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
    log_fatal "Unknown parameter ($PARAM) with ${VALUE:-no value}"
    ;;
  esac
done

backup_values_yaml() {
  HELM_VERSION=$(kubectl exec -it admindash-0 -n dashbase -- helm ls |grep '^dashbase' |awk '{print $10}')
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
    log_info "No input dashbase version, no change in dashbase version"
    VERSION=$CURRENTVERSION
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
    echo "The entered dashbase version is created on $NEWVERSION_TIME"
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
kubectl exec -it admindash-0 -n dashbase -- bash -c "helm repo update"
chart_version=$(kubectl exec -it admindash-0 -n dashbase -- helm ls |grep '^dashbase' |awk '{print $10}')
FINDCHART=$(kubectl exec -it admindash-0 -n dashbase --  helm search repo dashbase --devel -l |grep -iv "dashbase/dashbase-" |grep "dashbase/dashbase" |grep -iv 0.0.0.0 |grep -c "$VERSION")
FINDCHARTX=$(kubectl exec -it admindash-0 -n dashbase --  helm search repo dashbase --devel -l |grep -iv "dashbase/dashbase-" |grep "dashbase/dashbase" |grep -iv 0.0.0.0 |grep -c "$CHARTVERSION")
STABLECHART=$(kubectl exec -it admindash-0 -n dashbase -- helm search repo dashbase -l |sed -e 1d |head -1 |awk '{print $2}')

# Case 1 user has not entered any chart version and dashbase version
if [[ "$CHARTVERSION" == "undefined" ]] && [[ "$VERSION" == "undefined" ]]; then
  echo "Both dashbase version and chart version are not provided"
  echo "checking previous chart version is used in the deployment"
  if [[ $chart_version == \>* ]]; then
    echo "current chart version is using latest devel, and will continue using devel chart version"
    # Case 1A  no chart version entered and will use current  devel version
    chartver="--devel"
  else
    echo "current chart version is $chart_version"
    echo "will use current chart version $chart_version"
    # Case 1B  no chart version entered and will use current non devel version
    chartver="--version $chart_version"
  fi
# Case 2 user has not entered any chart version but specify dashbase version
elif [[ "$CHARTVERSION" == "undefined" ]] && [[ "$VERSION" != "undefined"  ]]; then
  echo "Dashbase version is provided and chart version is not provided"
  echo "Finding the corresponding chart version $VERSION in dashbase helm repo"
  if [ "$FINDCHART" == "0" ]; then
    log_info "There is no dashbase chart version for $VERSION"
    log_info "This upgrade will use latest stable chart version $STABLECHART"
    # Case 2A no chart version entered and no matching dashbase version in dashbase helm repo, will use latest stable chart version
    chartver="--version $STABLECHART"
  else
    log_info "The dashbase chart version for $VERSION is found"
    # Case 2B no chart version entered but found matching dashbase version in dashbase helm repo, will use matched dashbase version for chart version
    chartver="--version $VERSION"
  fi
# Case 3 user want to use latest devel chart version
elif [[ "$CHARTVERSION" == "devel" ]]; then
  echo "Entered chart version is latest development version"
  chartver="--devel"

# Case 4 user want to use current chart version
elif [[ "$CHARTVERSION" == "current" ]]; then
  echo "Entered chart version is using current version $chart_version"
  chartver="--version $chart_version"

# Case 5 user enetered chart version
elif [[ "$CHARTVERSION" != "undefined" ]]; then
  echo "Entered chart version is $CHARTVERSION"
  echo "Checking entered chart version in dashbae helm repo"
  if [ "$FINDCHARTX" == "0" ]; then
    log_info "There is no dashbase chart version for entered chart version $CHARTVERSION"
    log_info "This upgrade will use latest stable chart version $STABLECHART"
    # Case 5A user entered chart version but is not found in dashbase helm repo, then will use latest stable chart version
    chartver="--version $STABLECHART"
  else
    log_info "The dashbase chart version for $CHARTVERSION is found"
    # Case 5B user entered chart version and is found on dashbase helm repo, will use entered chart version
    chartver="--version $CHARTVERSION"
  fi
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
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm repo update"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm upgrade dashbase dashbase/dashbase -f /data/dashbase-values.yaml --namespace dashbase $chartver &> /dev/null"
  kubectl exec -it admindash-0 -n dashbase -- helm ls -n dashbase |sed -e 1d |grep -iv ingress |awk '{print $1,$3,$8,$9,$10}'
  NEWREVISION=$(kubectl exec -it admindash-0 -n dashbase -- helm ls -n dashbase |sed -e 1d |grep -iv ingress |awk '{print $3}')
  USTATUS=$(kubectl exec -it admindash-0 -n dashbase -- helm ls -n dashbase |sed -e 1d |grep -iv ingress |awk '{print $8}')
  run_check "helm upgrade dashbase dashbase/dashbase -f /data/dashbase-values.yaml --namespace dashbase $chartver"
else
  log_info "using custom dashbase value file $VALUEFILE"
  kubectl cp "$VALUEFILE" dashbase/admindash-0:/data/
  DASHVALUEFILE=$(echo $VALUEFILE | rev | cut -d"/" -f1 | rev)
  check_chart_version
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm repo update"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm upgrade dashbase dashbase/dashbase -f /data/$DASHVALUEFILE --namespace dashbase $chartver &> /dev/null"
  kubectl exec -it admindash-0 -n dashbase -- helm ls -n dashbase |sed -e 1d |grep -iv ingress |awk '{print $1,$3,$8,$9,$10}'
  NEWREVISION=$(kubectl exec -it admindash-0 -n dashbase -- helm ls -n dashbase |sed -e 1d |grep -iv ingress |awk '{print $3}')
  USTATUS=$(kubectl exec -it admindash-0 -n dashbase -- helm ls -n dashbase |sed -e 1d |grep -iv ingress |awk '{print $8}')
  run_check "helm upgrade dashbase dashbase/dashbase -f /data/$DASHVALUEFILE --namespace dashbase $chartver"
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
