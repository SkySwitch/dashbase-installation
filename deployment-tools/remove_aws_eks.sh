#!/bin/bash

CMDS="curl tar unzip git kubectl eksctl aws"


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

function fail_if_empty() {
  [[ -z "$2" ]] && log_fatal "Parameter $1 must have a value."
  return 0
}

echo "$@" >setup_arguments
echo "$#" >no_arguments

while [[ $# -gt 0 ]]; do
  PARAM=${1%%=*}
  [[ "$1" == *"="* ]] && VALUE=${1#*=} || VALUE=""
  log_info "Parsing ($1)"
  shift 1

  case $PARAM in
  --region)
    fail_if_empty "$PARAM" "$VALUE"
    REGION=$VALUE
    ;;
    *)
    log_fatal "Unknown parameter ($PARAM) with ${VALUE:-no value}"
    ;;
  esac
done

run_by_root() {
if [[ $EUID -ne 0 ]]; then
   log_fatal "This script must be run as root"
fi
}

check_commands() {
  for x in $CMDS
     do command -v "$x" > /dev/null && continue || { log_fatal "$x command not found."; }
  done
}

check_uninstall_script() {
  # check if uninstall dashbase script is downloaded or not
  if [ -f dashbase-installation/deployment-tools/uninstall-dashbase.sh ]; then
    log_info "Dashbase uninstallation script is found"
  else
    log_infor "Dashbase uninstallation script is not found, downloading"
    /usr/bin/git clone https://github.com/dashbase/dashbase-installation.git
  fi
}

# main process below this line

run_by_root
check_commands
check_uninstall_script

OLDCLUSTERNAME=$(aws eks list-clusters --region us-west-2 --output  text |grep mydash |awk '{ print $2 }')

if [ -z "$REGION" ]; then log_fatal "Missing AWS region"; fi

if [ -z "$OLDCLUSTERNAME" ]; then
  log_fatal "There is no dashbase EKS cluster in AWS region $REGION"
elif [ "$(echo "$OLDCLUSTERNAME" |grep -c mydash)" -gt 1 ]; then
  log_fatal "There are multiple dashbase EKS cluster in AWS region $REGION"
else
  log_info "The EKS cluster used for dashbase is $OLDCLUSTERNAME on AWS region $REGION"
fi

# uninstall dashbase
log_info "Remove K8s resources created by Dashbase installation"
dashbase-installation/deployment-tools/uninstall-dashbase.sh

# remove RKS cluster
/usr/local/bin/eksctl delete cluster --name "$OLDCLUSTERNAME" --region "$REGION"







