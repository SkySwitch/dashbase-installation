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

check_license() {
  if [[ -z "$USERNAME" || -z "$LICENSE" ]]; then
    log_fatal "either username or license string is missing"
  elif [[ "$USERNAME" == "undefined" && "$LICENSE" == "undefined" ]]; then
    log_warning "No License information is entered, install without license"
  elif [[ "$USERNAME" != "undefined" && "$LICENSE" != "undefined" ]]; then
    log_info "Entered username is $USERNAME"
    log_info "Entered license string is $LICENSE"
  else
     log_fatal "Please check entered username and license string"
  fi
}

# Create dashbase-license.txt
  if [[ "$USERNAME" == "undefined" && "$LICENSE" == "undefined" ]]; then
    log_warning "No License information is entered, install without license, no change on default dashbase-values.yaml file"
  else
    log_info "update default dashbase-values.yaml file with entered license information"
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
  log_info "Update successful, enjoy your dashbase."
  rm -rf ./dashbase-license.txt
else
  log_fatal "Update failed, Please check logs."
fi





