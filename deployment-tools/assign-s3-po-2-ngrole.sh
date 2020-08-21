#!/bin/bash


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
  --nodename)
    fail_if_empty "$PARAM" "$VALUE"
    INSNODE=$VALUE
    ;;
  --region)
    fail_if_empty "$PARAM" "$VALUE"
    REGION=$VALUE
    ;;
  --bucketname)
    fail_if_empty "$PARAM" "$VALUE"
    BUCKETNAME=$VALUE
    ;;
  *)
    log_fatal "Unknown parameter ($PARAM) with ${VALUE:-no value}"
    ;;
  esac
done


INSPROFILENAME=$(aws ec2 describe-instances --region $REGION --filters "Name=private-dns-name,Values=$INSNODE" --query 'Reservations[*].Instances[*].[IamInstanceProfile.Arn]' --output text |cut -d "/" -f2)
log_info "The instance profile name assciated to the worker nodes is $INSPROFILENAME"

POARN=$(echo "aws iam list-policies --query 'Policies[?PolicyName==\`$BUCKETNAME\`].Arn' --output text |awk '{ print $1}'" | bash)
IAMINSROLE=$(aws iam get-instance-profile --instance-profile-name "$INSPROFILENAME" |grep RoleName |sed -e 's/\"//g' |sed -e 's/\,//g' |awk '{ print $2}')

log_info  "The instance role name associated to the worker nodegroup is $IAMINSROLE"
log_info  "attaching the iam policy $POARN to the role $IAMINSROLE"


aws iam attach-role-policy --policy-arn "$POARN" --role-name "$IAMINSROLE"
#check_role_policy
log_info "checking attached policy on the role $IAMINSROLE"
COUNTPO=$( aws iam list-attached-role-policies --role-name "$IAMINSROLE" --output text |grep -c "$POARN")
if [ "$COUNTPO" -eq "1" ]; then
    log_info "The s3 bucket access policy $POARN is attached to role $IAMINSROLE"
else
    log_fatal "The s3 bucket access policy $POARN is not attached to role $IAMINSROLE"
fi
