#!/bin/bash

openssl rand -hex 4 >randomstring2
RSTRING2=$(cat randomstring2)

CLUSTERNAME="dashbase-$RSTRING2"
CMDS="curl tar unzip git aws"
REGION="us-east-2"

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

echo "$@" >/tmp/setup_arguments
echo "$#" >/tmp/no_arguments

while [[ $# -gt 0 ]]; do
  PARAM=${1%%=*}
  [[ "$1" == *"="* ]] && VALUE=${1#*=} || VALUE=""
  log_info "Parsing ($1)"
  shift 1

  case $PARAM in
  --cluster_name)
    fail_if_empty "$PARAM" "$VALUE"
    CLUSTERNAME=$VALUE
    ;;
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
  for x in $CMDS; do
    command -v "$x" >/dev/null && continue || { log_fatal "$x command not found."; }
  done
}

BUCKETNAME="s3-$CLUSTERNAME"

# main process below this line
log_info "the S3 bucket that will be created with name $BUCKETNAME"
# create s3 bucket
create_s3() {
  if [ "$(aws s3 ls / |grep -c $BUCKETNAME)" -eq "1" ]; then
     log_info "S3 bucket already be created previously"
  else
     log_info "s3 bucekt with name %BUCKETNAME is not found, creating"
     aws s3 mb s3://$BUCKETNAME --region $REGION
     if [ "$(aws s3 ls s3://$BUCKETNAME > /dev/null; echo $?)" -eq "0" ]; then log_info "S3 bucket $BUCKETNAME created successfully"; else log_fatal "S3 bucket $BUCKETNAME failed to create"; fi
  fi
}

# update bucket policy json with BUCKETNAME
update_s3_policy_json() {
   # remove any previous mydash-s3.json file if exists
   rm -rf mydash-s3.json
   # download the mydash-s3.json from github
   curl -k https://raw.githubusercontent.com/dashbase/dashbase-installation/master/deployment-tools/mydash-s3.json -o mydash-s3.json
   sed -i "s/MYDASHBUCKET/$BUCKETNAME/" mydash-s3.json
}

# create s3 bucket policy
create_s3_bucket_policy() {
  POARN=$(echo "aws iam list-policies --query 'Policies[?PolicyName==\`$BUCKETNAME\`].Arn' --output text |awk '{ print $1}'" | bash)
  if [ -z "$POARN" ]; then
     log_info "s3 bucket policy $BUCKETNAME not exists, and now creating"
     aws iam create-policy --policy-name $BUCKETNAME --policy-document file://mydash-s3.json
     POARN=$(echo "aws iam list-policies --query 'Policies[?PolicyName==\`$BUCKETNAME\`].Arn' --output text |awk '{ print $1}'" | bash)
     log_info "The s3 bucket policy ARN is $POARN"
  else
     log_info "s3 bucket policy $POARN exists"
  fi
}

# attach the s3 bucket policy to the EKS worker nodegroup instance profile
insert_s3_policy_to_nodegroup() {
  INSNODE=$(kubectl get nodes  |tail  -1 |awk '{print $1}')
  INSPROFILENAME=$(aws ec2 describe-instances --region $REGION --filters "Name=network-interface.private-dns-name,Values=$INSNODE" --query 'Reservations[*].Instances[*].[IamInstanceProfile.Arn]' --output text |cut -d "/" -f2)
  log_info "The instance profile name assciated to the worker nodes is $INSPROFILENAME"
  POARN=$(echo "aws iam list-policies --query 'Policies[?PolicyName==\`$BUCKETNAME\`].Arn' --output text |awk '{ print $1}'" | bash)

  IAMINSROLE=$(aws iam get-instance-profile --instance-profile-name "$INSPROFILENAME" |grep RoleName |sed -e 's/\"//g' |sed -e 's/\,//g' |awk '{ print $2}')
  log_info "The instance role name associated to the worker nodegroup is $IAMINSROLE"
  log_info "attaching the iam policy $POARN to the role $IAMINSROLE"
  aws iam attach-role-policy --policy-arn "$POARN" --role-name "$IAMINSROLE"
  #check_role_policy
  log_info "checking attached policy on the role $IAMINSROLE"
  COUNTPO=$( aws iam list-attached-role-policies --role-name "$IAMINSROLE" --output text |grep -c "$POARN")
  if [ "$COUNTPO" -eq "1" ]; then
    log_info "The s3 bucket access policy $POARN is attached to role $IAMINSROLE"
  else
    log_fatal "The s3 bucket access policy $POARN is not attached to role $IAMINSROLE"
  fi

}
#run_by_root
check_commands
create_s3
update_s3_policy_json
create_s3_bucket_policy
insert_s3_policy_to_nodegroup
