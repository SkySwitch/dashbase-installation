#!/bin/bash

RANDOM=$(openssl rand -hex 2 > randomstring)
RSTRING=$(cat randomstring)

AWS_ACCESS_KEY="undefined"
AWS_SECRET_ACCESS_KEY="undefined"
REGION="us-east-2"
INSTYPE="r5.2xlarge"
NODENUM=3
CLUSTERNAME="mydash$RSTRING"
ZONE="a"

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
  --install_dashbase)
    INSTALL_DASHBASE="true"
    ;;
  --small_setup)
    SMALL_SETUP="true"
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


check_input() {
  # checking required input arguments
  if [ "$AWS_ACCESS_KEY" == "undefined" ] || [ "$AWS_SECRET_ACCESS_KEY" == "undefined" ]; then
    log_fatal "Missing either AWS access key id or secret"
  else
    log_info "Entered aws access key id = $AWS_ACCESS_KEY"
    log_info "Entered aws secret access key = $AWS_SECRET_ACCESS_KEY"
    log_info "Default AWS region = $REGION"
    log_info "Instance type used on EKS cluster = $INSTYPE"
    log_info "Number of worker nodes in EKS cluster = $NODENUM"
    log_info "The EKS cluster name = $CLUSTERNAME"
    log_info "The EKS cluster nodegroup is located on $REGION$ZONE"
  fi
}

check_docker_helper() {
  # check previous docker-helper container exists or not
  if [ -n "$(docker ps -a | grep docker-helper | awk '{print $1}')" ]; then
    log_fatal "previous dashbase docker-helper container already exists"
  else
    log_info "no dashbase docker-helper is found, create a new one"
  fi
}

setup_docker_helper() {
  mkdir -p data
  docker run -itd --name docker-helper  -v data:/data rluiarch/dashbase-admin:1.3
  echo "Please wait until docker-helper container is ready"
  sleep 120 &
  show_spinner "$!"

  # check if docker container is created or not
  while [ "$(docker ps -a | grep docker-helper | awk '{ print $7 }')" != "Up" ] && [ $SECONDS -lt 180 ]; do echo -n "#"; done

  if [ "$(docker ps -a | grep docker-helper | awk '{print $7 }')" != "Up" ]; then
    log_fatal "Creating dashbase docker-helper container is failed"
  else
    log_info "Dashbase docker-helper is successfully created"
  fi
}

backup_aws_keys() {
  # Backup the entered AWS credentials in docker-helper's stateful volume
  log_info "Backup the AWS credentials in the docker-helper's stateful volume /data"
  echo "$REGION" > data/regionfile
  docker exec -it docker-helper /bin/bash -c "tar -cvf /data/aws_credential_$(date +%d%m%Y_%H%M%S).tar -C /root .aws"
  NEWAWSCTAR=$(docker exec -it docker-helper ls -ltr /data/ |tail -1 |awk '{print $NF}' |tr -d '\r')
  echo "Backup aws credential to your current path data folder"
  docker cp docker-helper:/data/"$NEWAWSCTAR" ./data/
}

setup_eks_cluster() {
  # Setup AWS CLI with provided Access key inside the docker-helper container
  # check if aws command is ready or not
  while [ "$(docker exec -it docker-helper ls -al /usr/local/bin |grep -c aws)" -eq 1 ] && [ $SECONDS -lt 120 ]; do echo -n "#"; done
  docker exec -it docker-helper /bin/bash -c "/bin/rm -rf /root/.aws"
  docker exec -it docker-helper /bin/bash -c "/usr/local/bin/aws --profile default configure set aws_access_key_id $AWS_ACCESS_KEY"
  docker exec -it docker-helper /bin/bash -c "/usr/local/bin/aws --profile default configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY"
  docker exec -it docker-helper /bin/bash -c "/usr/local/bin/aws --profile default configure set region $REGION"
  docker exec -it docker-helper /bin/bash -c "/usr/local/bin/aws configure list"

  docker exec -it docker-helper wget https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_Linux_amd64.tar.gz
  docker exec -it docker-helper tar -zxvf /dashbase/eksctl_Linux_amd64.tar.gz -C /usr/local/bin
  docker exec -it docker-helper chmod 755 /usr/local/bin/eksctl

  if [ "$(docker exec -it docker-helper /usr/local/bin/aws ec2 describe-vpcs --region $REGION --output text |grep -c VPCS)" -lt 9 ]; then
    log_info "creating AWS eks cluster, please wait and this process may take up to 15-20 minutes"
    docker exec -it docker-helper /usr/local/bin/eksctl create cluster --managed --name $CLUSTERNAME --region $REGION --version 1.14 --node-type $INSTYPE --nodegroup-name standard-workers --nodes $NODENUM --node-zones $REGION$ZONE --nodes-max $NODENUM --nodes-min $NODENUM
  else
    log_fatal "The specified EKS cluser region may not have sufficient capacity for additional VPC"
  fi
}

check_eks_cluster() {
  # check AWS EKS cluster status
  while [ -z "$(docker exec -it docker-helper /usr/local/bin/aws eks list-clusters --region $REGION --output text |awk '{print $2}' |grep $CLUSTERNAME)" ] &&  [ $SECONDS -lt 30 ]; do echo -n "#" ; done
  if [ "$(docker exec -it docker-helper /usr/local/bin/aws eks describe-cluster --name $CLUSTERNAME --region $REGION |grep status |awk '{print $2}' |sed -e 's/\"//g' |sed -e 's/\,//g' |tr -d '\r')" == "ACTIVE" ]; then
    log_info "The EKS cluster $CLUSTERNAME is ACTIVE and ready"
  else
    log_fatal "The EKS cluster $CLUSTERNAME status is not ACTIVE"
  fi

}

setup_dashbase() {

  if [ "$INSTALL_DASHBASE" == "true" ]; then
    log_info "Install dashbase option is entered. This will install dashbase on the previous created EKS cluster $CLUSTERNAME"
    echo "download dashbase software on the docker-helper container"
    docker exec -it docker-helper /bin/bash -c "/usr/bin/git clone https://github.com/dashbase/dashbase-installation.git"
    echo "setup and configure dashbase, this process will take up to 20-30 minutes"
    if  [ "$SMALL_SETUP" == "true" ]; then
      log_info "Dashbase small setup is selected"
      docker exec -it docker-helper /bin/bash -c "/dashbase/dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws"
    else
      log_info "Regular dashbase setup is selected"
      docker exec -it docker-helper /bin/bash -c "/dashbase/dashbase-installation/dashbase-installer.sh --platform=aws"
    fi
  else
    log_info "Install dashbase option is not selected, please run dashbase install script to setup your cluster"
  fi
}

# Main processes below this line

check_input
check_docker_helper
setup_docker_helper
backup_aws_keys
setup_eks_cluster
check_eks_cluster
setup_dashbase

