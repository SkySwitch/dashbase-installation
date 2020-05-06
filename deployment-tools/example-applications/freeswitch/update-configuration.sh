#!/usr/bin/env bash

ES_HOSTS="https://table-freeswitch:7888"
NAMESPACE="default"

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
  --es-hosts)
    fail_if_empty "$PARAM" "$VALUE"
    ES_HOSTS=$VALUE
    ;;
  --namespace)
    fail_if_empty "$PARAM" "$VALUE"
    NAMESPACE=$VALUE
    ;;
  *)
    log_fatal "Unknown parameter ($PARAM) with ${VALUE:-no value}"
    ;;
  esac
done

sed -i "" "s|FILEBEAT_ES_HOSTS|$ES_HOSTS|" ./resources/filebeat.yml
sed -i "" "s|FILEBEAT_ES_HOSTS|$ES_HOSTS|" ./resources/filebeat-loader.yml
sed -i "" "s|FREESWITCH_NAMESPACE|$NAMESPACE|" ./resources/config.yml
