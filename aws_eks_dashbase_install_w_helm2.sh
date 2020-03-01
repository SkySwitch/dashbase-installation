#!/bin/bash

RANDOM=$(openssl rand -hex 3 > randomstring)
RSTRING=$(cat randomstring)

AWS_ACCESS_KEY="undefined"
AWS_SECRET_ACCESS_KEY="undefined"
REGION="us-east-2"
HELM_VERSION="v2.14.3"
INSTYPE="r5.xlarge"
NODENUM=2
CLUSTERNAME="mydash$RSTRING"
CLUSTERSIZE="small"
ZONE="a"
SETUP_TYPE="ingress"
CMDS="curl tar unzip git openssl"

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

echo "$@" > /tmp/setup_arguments
echo "$#" > /tmp/no_arguments

while [[ $# -gt 0 ]]; do
  PARAM=${1%%=*}
  [[ "$1" == *"="* ]] && VALUE=${1#*=} || VALUE=""
  log_info "Parsing ($1)"
  shift 1

  case $PARAM in
  --aws_access_key)
    fail_if_empty "$PARAM" "$VALUE"
    AWS_ACCESS_KEY=$VALUE
    ;;
  --aws_secret_access_key)
    fail_if_empty "$PARAM" "$VALUE"
    AWS_SECRET_ACCESS_KEY=$VALUE
    ;;
  --region)
    fail_if_empty "$PARAM" "$VALUE"
    REGION=$VALUE
    ;;
  --instance_type)
    fail_if_empty "$PARAM" "$VALUE"
    INSTYPE=$VALUE
    ;;
  --nodes_number)
    fail_if_empty "$PARAM" "$VALUE"
    NODENUM=$VALUE
    ;;
  --cluster_name)
    fail_if_empty "$PARAM" "$VALUE"
    CLUSTERNAME=$VALUE
    ;;
  --cluster_size)
    fail_if_empty "$PARAM" "$VALUE"
    CLUSTERSIZE=$VALUE
    ;;
  --setup_type)
    fail_if_empty "$PARAM" "$VALUE"
    SETUP_TYPE=$VALUE
    ;;
  --subdomain)
    fail_if_empty "$PARAM" "$VALUE"
    SUBDOMAIN=$VALUE
    ;;
  --install_dashbase)
    INSTALL_DASHBASE="true"
    ;;
  *)
    log_fatal "Unknown parameter ($PARAM) with ${VALUE:-no value}"
    ;;
  esac
done

show_spinner() {
  local -r pid="${1}"
  local -r delay='0.75'
  local spinstr='\|/-'
  local temp
  while ps a | awk '{print $1}' | grep -q "${pid}"; do
    temp="${spinstr#?}"
    printf " [%c]  " "${spinstr}"
    spinstr=${temp}${spinstr%"${temp}"}
    sleep "${delay}"
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

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



check_input() {
  # checking required input arguments
  # if either AWS key or AWS secret is not present, script run will be fail and exit 1
  # Default installation will setup a small K8s cluster with two r5.xlarge worker nodes, if instance type and node mumber is not provided
  if [ "$AWS_ACCESS_KEY" == "undefined" ] || [ "$AWS_SECRET_ACCESS_KEY" == "undefined" ]; then
    log_fatal "Missing either AWS access key id or secret"
  elif [[ "$NODENUM" -lt 2 ]]; then
    log_fatal "Entered node number must be equal or greater than two"
  elif [ "$CLUSTERSIZE" != "small" ] && [ "$CLUSTERSIZE" != "large" ]; then
    log_fatal "Entered cluster size is invalid, only small or large is allowed"
  else
    log_info "Entered aws access key id = $AWS_ACCESS_KEY"
    log_info "Entered aws secret access key = $AWS_SECRET_ACCESS_KEY"
    log_info "Default AWS region = $REGION"
    if [ "$CLUSTERSIZE" == "large" ]; then 
       INSTYPE="r5.2xlarge"
       if [ "$NODENUM" -eq "2" ]; then  log_info "Change default node number from 2 to 3"; NODENUM=3; fi
    fi
    log_info "Instance type used on EKS cluster = $INSTYPE"
    log_info "Number of worker nodes in EKS cluster = $NODENUM"
    log_info "The EKS cluster name = $CLUSTERNAME"
    log_info "The EKS cluster nodegroup is located on $REGION$ZONE"
  fi
  if [ "$INSTALL_DASHBASE" == "true" ]; then
     log_info "Dashbase installation is selected"
      if [[ "$SETUP_TYPE" != "ingress" ]] && [[ "$SETUP_TYPE" != "lb" ]]; then
         log_fatal "Entered setup type is invalid, use either ingress or lb"
      else
         log_info "Entered dashbase setup type is $SETUP_TYPE"
      fi
      if [[ "$SETUP_TYPE" == "ingress" ]] && [[ -z "$SUBDOMAIN" ]]; then
        log_fatal "Missing subdomain flag, please enter subdomain value e.g. --subdomain=mysub.mydomain.com"
      elif [[ "$SETUP_TYPE" == "ingress" ]] && [[ -n "$SUBDOMAIN" ]]; then
        log_info "Entered subdomain is $SUBDOMAIN"
      fi
  else
     log_info "Dashbase installation is not selected"
  fi
}


setup_centos() {
  log_info "Install AWS CLI"
  curl https://s3.amazonaws.com/aws-cli/awscli-bundle-1.16.188.zip -o awscli-bundle.zip
  unzip -o awscli-bundle.zip
  awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws

  log_info "Configure AWS CLI"
  /usr/local/bin/aws --version
  /usr/local/bin/aws --profile default configure set aws_access_key_id $AWS_ACCESS_KEY
  /usr/local/bin/aws --profile default configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
  /usr/local/bin/aws --profile default configure set region $REGION
  sleep 5
  /usr/local/bin/aws configure list
  # install kubectl
  curl -k https://storage.googleapis.com/kubernetes-release/release/v1.17.0/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl
  chmod a+x /usr/local/bin/kubectl
  # install eksctl
  curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
  mv /tmp/eksctl /usr/local/bin
  chmod +x /usr/local/bin/eksctl
  # install helm
  curl -k https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -o  helm-${HELM_VERSION}-linux-amd64.tar.gz
  tar -zxvf helm-${HELM_VERSION}-linux-amd64.tar.gz
  cp linux-amd64/helm /usr/local/bin/
  chmod +x /usr/local/bin/helm
  export PATH=$PATH:/usr/local/bin/kubectl:/usr/local/bin/helm:/usr/local/bin/eksctl
}

check_previous_mydash() {
echo "Checking exiting EKS clusters in $REGION"
PREVIOUSEKS=$(aws eks list-clusters --region $REGION | grep mydash | sed -e 's/\"//g' | sed -e 's/^[ \t]*//')
if [ -z "$PREVIOUSEKS" ]; then
  log_info "No previous mydashXXXX EKS cluster detected"
else
  log_fatal "Previous mydashXXXX EKS clustername $PREVIOUSEKS is detected"
fi
}


setup_eks_cluster() {
  # Setup AWS CLI with provided Access key from the centos node

  if [ "$(/usr/local/bin/aws ec2 describe-vpcs --region $REGION --output text |grep -c VPCS)" -lt 9 ]; then
    log_info "creating AWS eks cluster, please wait. This process will take 15-20 minutes"
    /usr/local/bin/eksctl create cluster --managed --name $CLUSTERNAME --region $REGION --version 1.14 --node-type $INSTYPE --nodegroup-name standard-workers --nodes $NODENUM --node-zones $REGION$ZONE --nodes-max $NODENUM --nodes-min $NODENUM
  else
    log_fatal "Specified EKS cluser region may not have sufficient capacity for additional VPC"
  fi
}

check_eks_cluster() {
  # check AWS EKS cluster status
  while [ -z "$(/usr/local/bin/aws eks list-clusters --region $REGION --output text |awk '{print $2}' |grep $CLUSTERNAME)" ] &&  [ $SECONDS -lt 30 ]; do echo -n "#" ; done
  if [ "$(/usr/local/bin/aws eks describe-cluster --name $CLUSTERNAME --region $REGION |grep status |awk '{print $2}' |sed -e 's/\"//g' |sed -e 's/\,//g' |tr -d '\r')" == "ACTIVE" ]; then
    log_info "The EKS cluster $CLUSTERNAME is ACTIVE and ready"
  else
    log_fatal "The EKS cluster $CLUSTERNAME status is not ACTIVE"
  fi
  aws eks --region "$REGION" update-kubeconfig --name "$CLUSTERNAME"
  log_info "Checking K8s nodes"
  /usr/local/bin/kubectl get nodes
}

setup_dashbase() {

  if [ "$INSTALL_DASHBASE" == "true" ]; then
    log_info "Install dashbase option is entered. This will install dashbase on the previously created EKS cluster $CLUSTERNAME"
    echo "download dashbase software"
    /usr/bin/git clone https://github.com/dashbase/dashbase-installation.git
    echo "setup and configure dashbase, this process will take 20-30 minutes"
    if  [ "$CLUSTERSIZE" == "small" ]; then
      if [ "$SETUP_TYPE" == "ingress" ]; then
         log_info "Dashbase small setup with ingress controller endpoint is selected"
         dashbase-installation/deployment-tools/dashbase-installer-smallsetup_helm2.sh --platform=aws --ingress --subdomain=$SUBDOMAIN
      else
         log_info "Dashbase small setup with load balancer endpoint is selected"
         dashbase-installation/deployment-tools/dashbase-installer-smallsetup_helm2.sh --platform=aws
      fi
    elif [ "$CLUSTERSIZE" == "large" ]; then
      if [ "$SETUP_TYPE" == "ingress" ]; then
         log_info "Dashbase large setup with ingress controller endpoint is selected"
         dashbase-installation/dashbase-installer_helm2.sh --platform=aws --ingress --ingress --subdomain=$SUBDOMAIN
      else
         log_info "Dashbase small setup with load balancer endpoint is selected"
         dashbase-installation/dashbase-installer_helm2.sh --platform=aws
      fi
    fi
  else
    log_info "Install dashbase option is not selected, please run dashbase install script to setup your cluster"
  fi
}


# main process below this line
run_by_root
check_commands
check_input
setup_centos
check_previous_mydash
setup_eks_cluster
check_eks_cluster
setup_dashbase

