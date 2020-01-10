#!/bin/bash

AWS_ACCESS_KEY="undefined"
AWS_SECRET_ACCESS_KEY="undefined"
REGION="undefined"

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
  *)
    log_warning "Unknown parameter ($PARAM) with ${VALUE:-no value}"
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

setup_docker_helper() {
  docker run -itd --name docker-helper  -v data:/data rluiarch/dashbase-admin:1.3
  #docker run -itd --name docker-helper  --mount source=data,target=/data rluiarch/dashbase-admin:1.3
  #docker run -itd --name docker-helper rluiarch/dashbase-admin:1.3
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

setup_aws_cli() {
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

# main process below this line
mkdir -p data
AWSCTAR=$(ls -ltr data/*.tar |tail -1 |awk '{print $NF}')
CURRENTDOCKER=$(docker ps -aq --filter name=docker-helper)

# check if previous docker-helper exits, if it does, delete it
if [ -z "$CURRENTDOCKER" ]; then
  log_info "no previous docker-helper container detected in this host"
else
  log_info "Previous docker-helper container is detected"
  echo "Removing the previous docker-helper container"
  docker stop "$CURRENTDOCKER"
  docker rm "$CURRENTDOCKER" --force
  sleep 10
fi

if [ "$AWS_ACCESS_KEY" == "undefined" ] || [ "$AWS_SECRET_ACCESS_KEY" == "undefined" ]; then
  log_info "No input information for AWS access keys"
  echo "Checking if previous AWS credentials is saved"
  if [ -z  "$AWSCTAR" ]; then
    log_warning "Previous backup of AWS credential tar ball doesn't exist"
    log_fatal "Neither AWS access keys not entered nor previous AWS crendential file not found, please enter your AWS access keys"
  else
    log_info "Using previous AWS credntials from the latest backup"
    mkdir -p workdir
    tar -xf "$AWSCTAR" -C workdir
    AWS_ACCESS_KEY=$(cat workdir/.aws/credentials |grep aws_access_key_id |awk '{ print $3}')
    AWS_SECRET_ACCESS_KEY=$(cat workdir/.aws/credentials |grep aws_secret_access_key |awk '{print $3}')
    if [ -f data/regionfile ] && [ "$REGION" == "undefined" ]; then
      REGION=$(cat data/regionfile)
      log_info "Previous region file exists, using previous entered region $REGION"
    elif [ "$REGION" != "undefined" ]; then
      log_info "Entered region is $REGION"
    else
      log_fatal "Neither no previous region exists nor no region flag entered, please enter your AWS region"
    fi
    setup_docker_helper
    setup_aws_cli
    rm -rf workdir
  fi
else
  if [ "$REGION" == "undefined" ]; then
    log_fatal "Missing region flag, please enter your AWS region"
  else
    log_info "Entered aws_access_key_id is $AWS_ACCESS_KEY"
    log_info "Entered aws_secret_access_key is $AWS_SECRET_ACCESS_KEY"
    log_info "Entered region is $REGION"
    setup_docker_helper
    setup_aws_cli
  fi
fi

backup_aws_keys





