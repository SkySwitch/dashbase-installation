#!/bin/bash

# This script requires openssl
command -v openssl > /dev/null
if [[ "${?}" -ne 0 ]]; then
  printf "openssl is not installed, exiting\\n"
  exit 1
fi

RANDOM=$(openssl rand -hex 3 > randomstring)
RSTRING=$(cat randomstring)

AWS_EKS_SCRIPT_VERSION="1.4.0"
AWS_ACCESS_KEY="undefined"
AWS_SECRET_ACCESS_KEY="undefined"
REGION="us-east-2"
HELM_VERSION="v3.1.1"
INSTYPE="r5.xlarge"
NODENUM=2
CLUSTERNAME="mydash$RSTRING"
CLUSTERSIZE="small"
ZONEA="a"
ZONEB="b"
ZONEC="c"
SETUP_TYPE="ingress"
CMDS="curl tar unzip git openssl"
AUTHUSERNAME="undefined"
AUTHPASSWORD="undefined"
V2_FLAG="false"
BASIC_AUTH="false"
KUBECTLVERSION="1.15"
CDR_FLAG="false"
UCAAS_FLAG="false"


echo "AWS EKS setup script version is $AWS_EKS_SCRIPT_VERSION"

display_help() {
  echo "Usage: $0 [options...]"
  echo ""
  echo "   all options usage  e.g. --option_key=value  or --option_key"
  echo ""
  echo "     --aws_access_key         AWS ACCESS KEY "
  echo "                              e.g. --aws_access_key=YOURAWSACCESSKEY"
  echo "     --aws_secret_access_key  AWS SECRET ACCESS KEY"
  echo "                              e.g. --aws_secret_access_key=YOURACESSSECRETACCESSKEY"
  echo "     --region                 AWS region e.g. --region=us-west-2"
  echo "     --instance_type          AWS instance type, default is r5.xlarge"
  echo "                              e.g. --instance_type=c5.2xlarge"
  echo "     --nodes_number           number of EKS worker nodes, default is 2"
  echo "                              e.g. --nodes_number=4"
  echo "     --cluster_name           EKS cluster name, default is mydash appends 6 characters"
  echo "                              e.g. --cluster_name=myclustername"
  echo "     --cluster_size           default sizing, choice between small or large, default is small"
  echo "                              e.g. --cluster_size=large"
  echo "     --setup_type             default expose endpoints method, choice between ingree or lb"
  echo "                              default setup_type is ingress, e.g. --setup_type=lb"
  echo "     --subdomain              subdomain is required for default setup_type = ingress"
  echo "                              e.g. --subdomain=test.dashbase.io"
  echo "     --install_dashbase       setup dashbase after EKS setup complete, e.g. --install_dashbase"
  echo "     --basic_auth             enable basic auth on web UX, e.g. --basic_auth"
  echo "     --authusername           basic auth username, use together with basic_auth option"
  echo "                              e.g. --authusername=admin"
  echo "     --authpassword           basic auth password, use together with authusername option"
  echo "                              e.g. --authpassword=dashbase"
  echo "     --v2                     setup dashbase V2, e.g.  --v2"
  echo ""
  echo "   Command example in V1"
  echo "   ./aws_eks_dashbase_install.sh --aws_access_key=YOURAWSACCESSKEY \ "
  echo "                                 --aws_secret_access_key=YOURACESSSECRETACCESSKEY \ "
  echo "                                 --region=us-west-2 --subdomain=test.dashase.io  \ "
  echo "                                 --install_dashbase --basic_auth\ "
  echo "                                 --authusername=admin \ "
  echo "                                 --authpassword=dashbase"
  echo ""
  echo "   Command example in V2"
  echo "   ./aws_eks_dashbase_install.sh --v2 --aws_access_key=YOURAWSACCESSKEY \ "
  echo "                                 --aws_secret_access_key=YOURACESSSECRETACCESSKEY \ "
  echo "                                 --region=us-west-2 --subdomain=test.dashase.io  \ "
  echo "                                 --install_dashbase --basic_auth\ "
  echo "                                 --authusername=admin \ "
  echo "                                 --authpassword=dashbase"
  echo ""
  exit 0
}

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
  --help)
    display_help
    ;;
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
  --authusername)
    fail_if_empty "$PARAM" "$VALUE"
    AUTHUSERNAME=$VALUE
    ;;
  --authpassword)
    fail_if_empty "$PARAM" "$VALUE"
    AUTHPASSWORD=$VALUE
    ;;
  --basic_auth)
    BASIC_AUTH="true"
    ;;
  --subdomain)
    fail_if_empty "$PARAM" "$VALUE"
    SUBDOMAIN=$VALUE
    ;;
  --install_dashbase)
    INSTALL_DASHBASE="true"
    ;;
  --cdr)
    CDR_FLAG="true"
    ;;
  --ucaas)
    UCAAS_FLAG="true"
    ;;
  --v2)
    V2_FLAG="true"
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

show_setup() {
 log_info "setup type is $SETUP_TYPE"
 log_info "basic auth is $BASIC_AUTH"
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

check_ostype() {
  if [[ $OSTYPE == *"darwin"* ]]; then
    WKOSTYPE="mac"
    log_fatal "Dedected current workstation is a $WKOSTYPE, this script only tested on linux"
    WKOSTYPE="mac"
  elif [[ $OSTYPE == *"linux"* ]]; then
    log_info "Dedected current workstation is a $WKOSTYPE"
    WKOSTYPE="linux"
  else
    log_fatal "This script is only tested on linux; and fail to detect the current worksattion os type"
  fi
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
       # uncomment the following line to make default large cluster size be 3 nodes
       #if [ "$NODENUM" -eq "2" ]; then  log_info "Change default node number from 2 to 3"; NODENUM=3; fi
    fi
    log_info "Instance type used on EKS cluster = $INSTYPE"
    log_info "Number of worker nodes in EKS cluster = $NODENUM"
    log_info "The EKS cluster name = $CLUSTERNAME"
    log_info "The EKS cluster nodegroup is located on $REGION$ZONEA"
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
  # the setup_centos function  will install aws cli, kubectl, eksctl and helm3
  # install aws cli
  if [ "$(command -v aws > /dev/null ; echo $?)" -eq "0" ]; then
    log_info "aws cli is already installed"
    aws --version
  else
    log_info "aws cli is not installed, installing it now"
     curl https://s3.amazonaws.com/aws-cli/awscli-bundle-1.16.188.zip -o awscli-bundle.zip
     unzip -o awscli-bundle.zip
     awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
  fi

  log_info "Configure AWS CLI"
  /usr/local/bin/aws --version
  /usr/local/bin/aws --profile default configure set aws_access_key_id $AWS_ACCESS_KEY
  /usr/local/bin/aws --profile default configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
  /usr/local/bin/aws --profile default configure set region $REGION
  sleep 5
  /usr/local/bin/aws configure list

  # install kubectl
  if [ "$(command -v kubectl > /dev/null ; echo $?)" -eq "0" ]; then
    log_info "kubectl is installed in this host"
    kubectl version --client --short=true
  else
     log_info "kubectl is not installed, installing it now"
     curl -k https://storage.googleapis.com/kubernetes-release/release/v1.17.0/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl
     chmod a+x /usr/local/bin/kubectl
  fi
  # install eksctl
  if [ "$(command -v eksctl > /dev/null ; echo $?)" -eq "0" ]; then
    log_info "eksctl is installed in this host"
    eksctl version
  else
    log_info "eksctl is not installed, installing it now"
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    mv /tmp/eksctl /usr/local/bin
    chmod +x /usr/local/bin/eksctl
  fi
  # install helm 3
  if [ "$(command -v helm > /dev/null ; echo $?)" -eq "0" ]; then
    log_info "helm is installed, checking helm version"
     # check helm version 2 or 3
     if [ "$( helm version --client |grep -c "v3." )" -eq "1" ]; then log_info "this is helm3"; else log_fatal "helm2 is detected, please uninstall it before proceeding"; fi
  else
    log_info "helm 3 is not installed, isntalling it now"
    curl -k https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz -o  helm-${HELM_VERSION}-linux-amd64.tar.gz
    tar -zxvf helm-${HELM_VERSION}-linux-amd64.tar.gz
    cp linux-amd64/helm /usr/local/bin/
    chmod +x /usr/local/bin/helm
  fi

  # export all command path
  export PATH=$PATH:/usr/local/bin/kubectl:/usr/local/bin/helm:/usr/local/bin/eksctl
}

check_basic_auth() {
  # check basic auth input
  if [ "$BASIC_AUTH" != "true" ]; then
    log_info "Basic auth setting is not selected"
  else
    log_info "Basic auth is selected and checks input auth username and password"
    if [ "$AUTHUSERNAME" == "undefined" ] | [ "$AUTHPASSWORD" == "undefined" ]; then
      log_fatal "Either basic auth username or password is not entered"
    else
      if  [[ "$AUTHUSERNAME" =~ [^a-zA-Z0-9] ]] && [[ "$AUTHPASSWORD" =~ [^a-zA-Z0-9] ]]  ; then
        log_fatal "The entered auth username or password is not alphanumeric"
      else
         log_info "The entered auth usermane is $AUTHUSERNAME"
         log_info "The entered auth password is $AUTHPASSWORD"
      fi
    fi
  fi
  # check basic auth dependency
  # basic auth only works in ingres and requires ingress be true and non null subdomain string
  if [ "$BASIC_AUTH" == "true" ] && [ "$SETUP_TYPE" != "ingress" ]; then
    log_fatal "Basic auth is selected but not setup type is not selecting ingress, please check your options"
  elif [ "$BASIC_AUTH" == "true" ] && [ -z "$SUBDOMAIN" ]; then
    log_fatal "Basic auth is selected but not providing --subdomain=sub.example.com string for installer script"
  fi
}

check_previous_mydash() {
  echo "Checking exiting EKS clusters in $REGION"
  PREVIOUSEKS=$(aws eks list-clusters --region $REGION | grep mydash | sed -e 's/\"//g' | sed -e 's/^[ \t]*//')
  if [ -z "$PREVIOUSEKS" ]; then
    log_info "No previous mydashXXXXXX EKS cluster detected"
  else
    log_fatal "Previous mydashXXXXXX EKS clustername $PREVIOUSEKS is detected"
  fi
}

check_max_vpc_limit() {
  echo "Checking the current number of VPC in the region $REGION"
  VPC_LIMIT=$(aws service-quotas get-service-quota --service-code 'vpc' --region $REGION --quota-code 'L-F678F1CE' --output text |awk '{print $NF}' |awk '{$0=int($0)}1')
  log_info "The max vpc limit in the region $REGION is $VPC_LIMIT"
}

setup_eks_cluster() {
  # Setup AWS EKS cluster with provided AWS Access key from the centos nodea
  # verify vpc max limit is int or not
  if [[ $VPC_LIMIT =~ ^-?[0-9]+$ ]]; then
    log_info "Checking VPC max limit value and  is an integer and is equal to $VPC_LIMIT" 
  else  
    log_warning "The detected VPC max limit is not an integer, something may be wrong, and will use default vpc max limit in the region $REGION and is 5"
    VPC_LIMIT="5"
  fi

  # compare vpc count with max vpc limit , the vpc count should be less than vpc limit
  if [ "$(/usr/local/bin/aws ec2 describe-vpcs --region $REGION --output text |grep -c VPCS)" -lt $VPC_LIMIT ]; then
    log_info "creating AWS eks cluster, please wait. This process will take 15-20 minutes"
    date +"%T"
    echo "/usr/local/bin/eksctl create cluster --managed --name $CLUSTERNAME --region $REGION --version $KUBECTLVERSION --node-type $INSTYPE --nodegroup-name standard-workers --zones $REGION$ZONEA,$REGION$ZONEB --nodes $NODENUM --node-zones $REGION$ZONEA --nodes-max $NODENUM --nodes-min $NODENUM"
    /usr/local/bin/eksctl create cluster --managed --name $CLUSTERNAME --region $REGION --version $KUBECTLVERSION --node-type $INSTYPE --nodegroup-name standard-workers --zones $REGION$ZONEA,$REGION$ZONEB --nodes $NODENUM --node-zones $REGION$ZONEA --nodes-max $NODENUM --nodes-min $NODENUM
    date +"%T"
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

# Define bucketname
BUCKETNAME="s3-$CLUSTERNAME"

create_s3() {
  if [ "$(aws s3 ls / |grep -c $BUCKETNAME)" -eq "1" ]; then
     log_info "S3 bucket already be created previously"
  else
     log_info "s3 bucekt with name %BUCKETNAME is not found, creating"
     aws s3 mb s3://$BUCKETNAME --region $REGION
     if [ "$(aws s3 ls s3://$BUCKETNAME > /dev/null; echo $?)" -eq "0" ]; then log_info "S3 bucket $BUCKETNAME created successfully"; else log_fatal "S3 bucket $BUCKETNAME failed to create"; fi
  fi
}

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
  log_info "attaching the s3 bucket policy $POARN to the role $IAMINSROLE"
  aws iam attach-role-policy --policy-arn "$POARN" --role-name "$IAMINSROLE"
  #check_role_policy
  log_info "checking attached s3 bucket policy on the role $IAMINSROLE"
  COUNTPO=$( aws iam list-attached-role-policies --role-name "$IAMINSROLE" --output text |grep -c "$POARN")
  if [ "$COUNTPO" -eq "1" ]; then
    log_info "The s3 bucket access policy $POARN is attached to role $IAMINSROLE"
  else
    log_fatal "The s3 bucket access policy $POARN is not attached to role $IAMINSROLE"
  fi
}

V1_dashbase() {
    if  [ "$CLUSTERSIZE" == "small" ]; then
      if [ "$SETUP_TYPE" == "ingress" ] && [ "$BASIC_AUTH" == "false" ]; then
         log_info "Dashbase small setup with ingress controller endpoint and no basic auth is selected"
         # checking ucass and cdr flag is selected or not
         if [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "true" ]; then
           log_info "UCAAS and CDR option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --ingress --subdomain=$SUBDOMAIN --cdr --ucaas
         elif [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "UCASS option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --ingress --subdomain=$SUBDOMAIN --ucaas
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "true" ]; then
           log_warning "only CDR option is selected and missing UCAAS option, will install default without UCAAS"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --ingress --subdomain=$SUBDOMAIN
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "no UCAAS and CDR option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --ingress --subdomain=$SUBDOMAIN
          fi
      elif [ "$SETUP_TYPE" == "ingress" ] && [ "$BASIC_AUTH" == "true" ]; then
         log_info "Dashbase small setup with ingress controller endpoint and basic auth is selected"
         # checking ucass and cdr flag is selected or not
         if [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "true" ]; then
           log_info "UCAAS and CDR option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --ingress --subdomain=$SUBDOMAIN --basic_auth --authusername=$AUTHUSERNAME --authpassword=$AUTHPASSWORD --cdr --ucaas
         elif [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "UCASS option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --ingress --subdomain=$SUBDOMAIN --basic_auth --authusername=$AUTHUSERNAME --authpassword=$AUTHPASSWORD --ucaas
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "true" ]; then
           log_warning "only CDR option is selected and missing UCAAS option, will install default without UCAAS"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --ingress --subdomain=$SUBDOMAIN --basic_auth --authusername=$AUTHUSERNAME --authpassword=$AUTHPASSWORD
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "no UCAAS and CDR option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --ingress --subdomain=$SUBDOMAIN --basic_auth --authusername=$AUTHUSERNAME --authpassword=$AUTHPASSWORD
         fi
      else
         log_info "Dashbase small setup with load balancer endpoint is selected"
         # checking ucass and cdr flag is selected or not
         if [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "true" ]; then
           log_info "UCAAS and CDR option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --cdr --ucaas
         elif [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "UCASS option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --ucaas
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "true" ]; then
           log_warning "only CDR option is selected and missing UCAAS option, will install default without UCAAS"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "no UCAAS and CDR option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws
        fi
      fi
    elif [ "$CLUSTERSIZE" == "large" ]; then
      if [ "$SETUP_TYPE" == "ingress" ] && [ "$BASIC_AUTH" == "false" ]; then
         log_info "Dashbase large setup with ingress controller endpoint and no basic auth is selected"
         # checking ucass and cdr flag is selected or not
         if [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "true" ]; then
           log_info "UCAAS and CDR option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --ingress --subdomain=$SUBDOMAIN --cdr --ucaas
         elif [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "UCASS option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --ingress --subdomain=$SUBDOMAIN --ucaas
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "true" ]; then
           log_warning "only CDR option is selected and missing UCAAS option, will install default without UCAAS"
           dashbase-installation/dashbase-installer.sh --platform=aws --ingress --subdomain=$SUBDOMAIN
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "no UCAAS and CDR option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --ingress --subdomain=$SUBDOMAIN
         fi
      elif [ "$SETUP_TYPE" == "ingress" ] && [ "$BASIC_AUTH" == "true" ]; then
         log_info "Dashbase large setup with ingress controller endpoint and basic auth is selected"
         # checking ucass and cdr flag is selected or not
         if [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "true" ]; then
           log_info "UCAAS and CDR option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --ingress --subdomain=$SUBDOMAIN --basic_auth --authusername=$AUTHUSERNAME --authpassword=$AUTHPASSWORD --cdr --ucaas
         elif [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "UCASS option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --ingress --subdomain=$SUBDOMAIN --basic_auth --authusername=$AUTHUSERNAME --authpassword=$AUTHPASSWORD --ucaas
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "true" ]; then
           log_warning "only CDR option is selected and missing UCAAS option, will install default without UCAAS"
           dashbase-installation/dashbase-installer.sh --platform=aws --ingress --subdomain=$SUBDOMAIN --basic_auth --authusername=$AUTHUSERNAME --authpassword=$AUTHPASSWORD
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "no UCAAS and CDR option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --ingress --subdomain=$SUBDOMAIN --basic_auth --authusername=$AUTHUSERNAME --authpassword=$AUTHPASSWORD
         fi
      else
         log_info "Dashbase small setup with load balancer endpoint is selected"
         # checking ucass and cdr flag is selected or not
         if [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "true" ]; then
           log_info "UCAAS and CDR option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --cdr --ucaas
         elif [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "UCASS option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --ucaas
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "true" ]; then
           log_warning "only CDR option is selected and missing UCAAS option, will install default without UCAAS"
           dashbase-installation/dashbase-installer.sh --platform=aws
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "no UCAAS and CDR option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws
         fi
      fi
    fi
}

V2_dashbase() {
    if  [ "$CLUSTERSIZE" == "small" ]; then
      if [ "$SETUP_TYPE" == "ingress" ] && [ "$BASIC_AUTH" == "false" ]; then
         log_info "Dashbase small setup with ingress controller endpoint and no basic auth is selected"
         # checking ucass and cdr flag is selected or not
         if [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "true" ]; then
           log_info "UCAAS and CDR option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --v2 --ingress --subdomain=$SUBDOMAIN --bucketname=$BUCKETNAME --cdr --ucaas
         elif [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "UCASS option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --v2 --ingress --subdomain=$SUBDOMAIN --bucketname=$BUCKETNAME --ucaas
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "true" ]; then
           log_warning "only CDR option is selected and missing UCAAS option, will install default without UCAAS"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --v2 --ingress --subdomain=$SUBDOMAIN --bucketname=$BUCKETNAME
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "no UCAAS and CDR option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --v2 --ingress --subdomain=$SUBDOMAIN --bucketname=$BUCKETNAME
         fi
      elif [ "$SETUP_TYPE" == "ingress" ] && [ "$BASIC_AUTH" == "true" ]; then
         log_info "Dashbase small setup with ingress controller endpoint and basic auth is selected"
         # checking ucass and cdr flag is selected or not
         if [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "true" ]; then
           log_info "UCAAS and CDR option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --v2 --ingress --subdomain=$SUBDOMAIN --basic_auth --authusername=$AUTHUSERNAME --authpassword=$AUTHPASSWORD --bucketname=$BUCKETNAME --cdr --ucaas
         elif [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "UCASS option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --v2 --ingress --subdomain=$SUBDOMAIN --basic_auth --authusername=$AUTHUSERNAME --authpassword=$AUTHPASSWORD --bucketname=$BUCKETNAME --ucaas
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "true" ]; then
           log_warning "only CDR option is selected and missing UCAAS option, will install default without UCAAS"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --v2 --ingress --subdomain=$SUBDOMAIN --basic_auth --authusername=$AUTHUSERNAME --authpassword=$AUTHPASSWORD --bucketname=$BUCKETNAME
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "no UCAAS and CDR option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --v2 --ingress --subdomain=$SUBDOMAIN --basic_auth --authusername=$AUTHUSERNAME --authpassword=$AUTHPASSWORD --bucketname=$BUCKETNAME
        fi
      else
         log_info "Dashbase small setup with load balancer endpoint is selected"
         # checking ucass and cdr flag is selected or not
         if [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "true" ]; then
           log_info "UCAAS and CDR option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --v2 --bucketname=$BUCKETNAME --cdr --ucaas
         elif [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "UCASS option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --v2 --bucketname=$BUCKETNAME --ucaas
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "true" ]; then
           log_warning "only CDR option is selected and missing UCAAS option, will install default without UCAAS"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --v2 --bucketname=$BUCKETNAME
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "no UCAAS and CDR option is selected"
           dashbase-installation/deployment-tools/dashbase-installer-smallsetup.sh --platform=aws --v2 --bucketname=$BUCKETNAME
         fi
      fi
    elif [ "$CLUSTERSIZE" == "large" ]; then
      if [ "$SETUP_TYPE" == "ingress" ] && [ "$BASIC_AUTH" == "false" ]; then
         log_info "Dashbase large setup with ingress controller endpoint and no basic auth is selected"
         # checking ucass and cdr flag is selected or not
         if [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "true" ]; then
           log_info "UCAAS and CDR option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --v2 --ingress --subdomain=$SUBDOMAIN --bucketname=$BUCKETNAME --cdr --ucaas
         elif [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "UCASS option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --v2 --ingress --subdomain=$SUBDOMAIN --bucketname=$BUCKETNAME --ucaas
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "true" ]; then
           log_warning "only CDR option is selected and missing UCAAS option, will install default without UCAAS"
           dashbase-installation/dashbase-installer.sh --platform=aws --v2 --ingress --subdomain=$SUBDOMAIN --bucketname=$BUCKETNAME
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "no UCAAS and CDR option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --v2 --ingress --subdomain=$SUBDOMAIN --bucketname=$BUCKETNAME
         fi
      elif [ "$SETUP_TYPE" == "ingress" ] && [ "$BASIC_AUTH" == "true" ]; then
         log_info "Dashbase large setup with ingress controller endpoint and basic auth is selected"
         # checking ucass and cdr flag is selected or not
         if [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "true" ]; then
           log_info "UCAAS and CDR option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --v2 --ingress --subdomain=$SUBDOMAIN --basic_auth --authusername=$AUTHUSERNAME --authpassword=$AUTHPASSWORD --bucketname=$BUCKETNAME --cdr --ucaas
         elif [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "UCASS option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --v2 --ingress --subdomain=$SUBDOMAIN --basic_auth --authusername=$AUTHUSERNAME --authpassword=$AUTHPASSWORD --bucketname=$BUCKETNAME --ucaas
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "true" ]; then
           log_warning "only CDR option is selected and missing UCAAS option, will install default without UCAAS"
           dashbase-installation/dashbase-installer.sh --platform=aws --v2 --ingress --subdomain=$SUBDOMAIN --basic_auth --authusername=$AUTHUSERNAME --authpassword=$AUTHPASSWORD --bucketname=$BUCKETNAME
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "no UCAAS and CDR option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --v2 --ingress --subdomain=$SUBDOMAIN --basic_auth --authusername=$AUTHUSERNAME --authpassword=$AUTHPASSWORD --bucketname=$BUCKETNAME
         fi
      else
         log_info "Dashbase small setup with load balancer endpoint is selected"
         # checking ucass and cdr flag is selected or not
         if [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "true" ]; then
           log_info "UCAAS and CDR option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --v2 --bucketname=$BUCKETNAME --cdr --ucaas
         elif [ "$UCAAS_FLAG" == "true" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "UCASS option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --v2 --bucketname=$BUCKETNAME --ucaas
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "true" ]; then
           log_warning "only CDR option is selected and missing UCAAS option, will install default without UCAAS"
           dashbase-installation/dashbase-installer.sh --platform=aws --v2 --bucketname=$BUCKETNAME
         elif [ "$UCAAS_FLAG" == "false" ] && [ "$CDR_FLAG" == "false" ]; then
           log_info "no UCAAS and CDR option is selected"
           dashbase-installation/dashbase-installer.sh --platform=aws --v2 --bucketname=$BUCKETNAME
         fi
      fi
    fi
}

setup_dashbase() {
  if [ "$INSTALL_DASHBASE" == "true" ]; then
    log_info "Install dashbase option is entered. This will install dashbase on the previously created EKS cluster $CLUSTERNAME"
    echo "download dashbase software"
    /usr/bin/git clone https://github.com/dashbase/dashbase-installation.git
    echo "setup and configure dashbase, this process will take 20-30 minutes"
    if [ "$V2_FLAG" == "true" ]; then
      log_info "Dashbase V2 is selected"
      create_s3
      update_s3_policy_json
      create_s3_bucket_policy
      insert_s3_policy_to_nodegroup
      sleep 10
      V2_dashbase
    else
      log_info "Dashbase V1 is selected"
      V1_dashbase
    fi
  else
    log_info "Install dashbase option is not selected, please run dashbase install script to setup your cluster"
  fi
}

display_bucketname() {
  POARN=$(echo "aws iam list-policies --query 'Policies[?PolicyName==\`$BUCKETNAME\`].Arn' --output text |awk '{ print $1}'" | bash)
  IAMINSROLE=$(aws iam get-instance-profile --instance-profile-name "$INSPROFILENAME" |grep RoleName |sed -e 's/\"//g' |sed -e 's/\,//g' |awk '{ print $2}')
  if [ "$V2_FLAG" == "true" ]; then
    echo "The S3 bucket name used in dashbase V2 setup is $BUCKETNAME"
    echo "The S3 bucket policy is $POARN"
    echo "The IAM role attached with the s3 bucket policy is $IAMINSROLE"
  fi
}

# main process below this line
#{
run_by_root
check_ostype
check_commands
check_input
show_setup
check_basic_auth
setup_centos
check_previous_mydash
check_max_vpc_limit
setup_eks_cluster
check_eks_cluster
setup_dashbase
display_bucketname
#} 2>&1 | tee -a /tmp/aws_eks_setup_"$(date +%d-%m-%Y_%H-%M-%S)".log
