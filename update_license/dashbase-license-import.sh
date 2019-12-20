#!/bin/bash

USERNAME="undefined"
LICENSE="undefined"

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
  *)
    log_warning "Unknown parameter ($PARAM) with ${VALUE:-no value}"
    ;;
  esac
done

# Create dashbase-license.txt
  if [[ "$USERNAME" == "undefined" || "$LICENSE" == "undefined" ]]; then
    log_fatal "License information is not correct."
  else
    log_info "Update default dashbase-values.yaml file with entered license information"
    echo "username: \"$USERNAME\"" > dashbase-license.txt
    echo "license: \"$LICENSE\"" >> dashbase-license.txt
  fi

# Update dashbase license information
log_info "update default dashbase-values.yaml file with entered license information"
kubectl cp dashbase-license.txt dashbase/admindash-0:/dashbase/
kubectl cp update-license.sh dashbase/admindash-0:/dashbase/
kubectl exec -it admindash-0 -n dashbase -- bash -c "chmod +x /dashbase/update-license.sh"
kubectl exec -it admindash-0 -n dashbase -- bash -c "./update-license.sh"

if [[ $? = 0 ]]; then
  log_info "License update successful, enjoy your dashbase."
  rm -rf ./dashbase-license.txt
else
  log_fatal "License update failed."
fi





