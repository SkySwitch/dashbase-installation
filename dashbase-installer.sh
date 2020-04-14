#!/bin/bash

INSTALLER_VERSION="1.4.0"
PLATFORM="undefined"
INGRESS_FLAG="false"
V2_FLAG="false"
UCAAS_FLAG="false"
VALUEFILE="dashbase-values.yaml"
USERNAME="undefined"
LICENSE="undefined"
DASHVERSION="1.4.0"
AUTHUSERNAME="undefined"
AUTHPASSWORD="undefined"
BUCKETNAME="undefined"
STORAGE_ACCOUNT="undefined"
STORAGE_KEY="undefined"
PRESTO_FLAG="false"
TABLENAME="logs"
CDR_FLAG="false "

echo "Installer script version is $INSTALLER_VERSION"

display_help() {
  echo "Usage: $0 [options...]"
  echo ""
  echo "   all options usage e.g. --option_key=value  or --option_key"
  echo "     --platform     aws/azure/gce  e.g. --platform=aws"
  echo "     --version      dashbase version e.g. --version=1.3.2"
  echo "     --ingress      exposed dashbase services using ingress controller  e.g. --ingress"
  echo "     --subdomain    use together with ingress option e.g.  --subdomain=test.dashbase.io"
  echo "     --username     dashbase license username e.g. --username=myname"
  echo "     --license      dashbase license string  e.g. --license=my_license_string"
  echo "     --exposemon    expose dashbase prometheus and pushgateway endpoints when using LB (not ingress)"
  echo "                    e.g.  --exposemon"
  echo "     --basic_auth   use basic auth to secure dashbase web UX e.g.  --basic_auth"
  echo "                    basic auth requires authusername and authpassword options"
  echo "     --authusername basic auth username, use together with basic_auth option"
  echo "                    e.g. --authusername=admin"
  echo "     --authpassword basic auth password, use together with authusername option"
  echo "                    e.g. --authpassword=dashbase"
  echo "     --valuefile    specify a custom values yaml file"
  echo "                    e.g. --valuefile=/tmp/mydashbase_values.yaml"
  echo "     --presto       enable presto component e.g. --presto"
  echo "     --tablename        dashbase table name, default table name is logs"
  echo "                        e.g. --tablename=freeswitch"
  echo "     --ucaas        enable ucaas feature  e.g. --ucaas"
  echo "     --cdr          enable cdr log data for insight page  e.g. --cdr"
  echo "     --help         display command options and usage example"
  echo ""
  echo "   The following options only be used on V2 dashbase"
  echo "     --v2               setup dashbase V2"
  echo "     --bucketname       cloud object storage bucketname"
  echo "                        e.g. --bucketname=my-s3-bucket"
  echo "     --storage_account  cloud object storage account value, in AWS is the ACCESS KEY"
  echo "                        e.g. --storage_account=MYSTORAGEACCOUNTSTRING"
  echo "     --storage_key      cloud object storage key, in AWS is the ACCESS SECRET"
  echo "                        e.g. --storage_key=MYSTORAGEACCOUNTACCESSKEY"
  echo ""
  echo "   Command example in V1"
  echo "   ./dashbase-installer.sh --platform=aws --ingress --subdomain=test.dashbase.io"
  echo ""
  echo "   Command example in V2"
  echo "   ./dashbase-installer.sh --platform=aws --v2 --ingress \ "
  echo "                           --subdomain=test.dashase.io --bucketname=my-s3-bucket \ "
  echo "                           --storage_account=MYSTORAGEACCOUNTSTRING \ "
  echo "                           --storage_key=MYSTORAGEACCOUNTACCESSKEY \ "
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
  --subdomain)
    fail_if_empty "$PARAM" "$VALUE"
    SUBDOMAIN=$VALUE
    ;;
  --platform)
    fail_if_empty "$PARAM" "$VALUE"
    PLATFORM=$VALUE
    ;;
  --version)
    fail_if_empty "$PARAM" "$VALUE"
    VERSION=$VALUE
    ;;
  --valuefile)
    fail_if_empty "$PARAM" "$VALUE"
    VALUEFILE=$VALUE
    ;;
  --username)
    fail_if_empty "$PARAM" "$VALUE"
    USERNAME=$VALUE
    ;;
  --license)
    fail_if_empty "$PARAM" "$VALUE"
    LICENSE=$VALUE
    ;;
  --bucketname)
    fail_if_empty "$PARAM" "$VALUE"
    BUCKETNAME=$VALUE
    ;;
  --tablename)
    fail_if_empty "$PARAM" "$VALUE"
    TABLENAME=$VALUE
    ;;
  --v2)
    V2_FLAG="true"
    ;;
  --cdr)
    CDR_FLAG="true"
    ;;
  --authusername)
    fail_if_empty "$PARAM" "$VALUE"
    AUTHUSERNAME=$VALUE
    ;;
  --authpassword)
    fail_if_empty "$PARAM" "$VALUE"
    AUTHPASSWORD=$VALUE
    ;;
  --storage_account)
    fail_if_empty "$PARAM" "$VALUE"
    STORAGE_ACCOUNT=$VALUE
    ;;
  --storage_key)
    fail_if_empty "$PARAM" "$VALUE"
    STORAGE_KEY=$VALUE
    ;;
  --basic_auth)
    BASIC_AUTH="true"
    ;;
  --ingress)
    INGRESS_FLAG="true"
    ;;
  --exposemon)
    EXPOSEMON="--exposemon"
    ;;
  --ucaas)
    UCAAS_FLAG="true"
    ;;
  --presto)
    PRESTO_FLAG="true"
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

check_platform_input() {
  # check entered platform
  if [[ "$PLATFORM" == "undefined" || -z "$PLATFORM" ]]; then
    log_fatal "--platform is required"
  elif [ "$PLATFORM" == "aws" ]; then
    log_info "entered plaform type is $PLATFORM"
  elif [ "$PLATFORM" == "azure" ]; then
    log_info "entered plaform type is $PLATFORM"
  elif [ "$PLATFORM" == "gce" ]; then
    log_info "entered plaform type is $PLATFORM"
  else
    log_fatal "Incorrect platform type, and platform type should be either aws, gce, or azure"
  fi
}

check_ingress_subdomain() {
  if [[ "$INGRESS_FLAG" == "true" && -z "$SUBDOMAIN" ]]; then
    log_fatal "--subomain is required when using --ingress flag"
  elif [[ "$INGRESS_FLAG" == "true" && -n "$SUBDOMAIN" ]]; then
    log_info "entered subdomain is $SUBDOMAIN"
  elif [[ "$INGRESS_FLAG" == "false" && -n "$SUBDOMAIN" ]]; then
    log_warning "Ingress is not used but entered the subdomain name"
  fi
}

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

check_k8s_permission() {
  # check permission
  ## permissions required by dashbase charts
  echo "Checking your RBAC permission:"
  rm -rf check_k8_permission.txt
  echo -n "Admin permission in namespace dashbase: "
  kubectl auth can-i '*' '*' -n dashbase > >(tee -a check_k8_permission.txt) 2>&1
  echo -n "Admin permission on namespaces: "
  kubectl auth can-i '*' namespaces --all-namespaces > >(tee -a check_k8_permission.txt) 2>&1
  echo -n "Admin permission on nodes: "
  kubectl auth can-i '*' nodes --all-namespaces > >(tee -a check_k8_permission.txt) 2>&1
  echo -n "Admin permission on storageclasses: "
  kubectl auth can-i '*' storageclasses --all-namespaces > >(tee -a check_k8_permission.txt) 2>&1
  echo -n "Admin permission on persistentvolumes: "
  kubectl auth can-i '*' persistentvolumes --all-namespaces > >(tee -a check_k8_permission.txt) 2>&1
  echo -n "Admin permission on clusterroles: "
  kubectl auth can-i '*' clusterroles --all-namespaces > >(tee -a check_k8_permission.txt) 2>&1
  echo -n "Admin permission on clusterrolebindings: "
  kubectl auth can-i '*' clusterrolebindings --all-namespaces > >(tee -a check_k8_permission.txt) 2>&1
  echo -n "Admin permission on priorityclasses: "
  kubectl auth can-i '*' priorityclasses --all-namespaces > >(tee -a check_k8_permission.txt) 2>&1
  ## permission required by helm
  echo -n "Admin permission in namespace kube-system(required by helm): "
  kubectl auth can-i '*' '*' -n kubes-system > >(tee -a check_k8_permission.txt) 2>&1
  ## exit if K8 permission not met requirement
  if [ -z "$(cat check_k8_permission.txt | grep -iv yes)" ]; then
    echo "K8s permission met the requirement"
  else
    echo "The account don't have sufficient permission to access K8 cluster"
    exit 1
  fi
}

check_node_cpu() {
  ## check nodes resources
  if [[ "$2" =~ ^([0-9]+)m$ ]]; then
    if [[ ${BASH_REMATCH[1]} -ge 6000 ]]; then
      return 0
    fi
  elif [[ "$2" =~ ^([0-9]+)$ ]]; then
    if [[ ${BASH_REMATCH[1]} -ge 6 ]]; then
      return 0
    fi
  else
    echo "Can't determine the cpu($2) of node($1)."
  fi
  return 1
}

check_node_memory() {
  if [[ "$2" =~ ^([0-9]+)Ki?$ ]]; then
    if [[ ${BASH_REMATCH[1]} -ge 60000000 ]]; then
      return 0
    fi
  elif [[ "$2" =~ ^([0-9]+)Mi?$ ]]; then
    if [[ ${BASH_REMATCH[1]} -ge 60000 ]]; then
      return 0
    fi
  elif [[ "$2" =~ ^([0-9]+)Gi?$ ]]; then
    if [[ ${BASH_REMATCH[1]} -ge 60 ]]; then
      return 0
    fi
  else
    echo "Can't determine the memory($2) of node($1)."
  fi
  return 1
}

check_node() {
  if ! check_node_cpu "$1" "$2"; then
    echo "Node($1) doesn't have enough cpu resources(8 core at least)."
    return 0
  fi
  if ! check_node_memory "$1" "$3"; then
    echo "Node($1) doesn't have enough memory resources(64Gi at least)."
    return 0
  fi

  ((AVAIILABLE_NODES++))
  return 0
}

check_version() {
  if [ -z "$VERSION" ]; then
    VERSION=$DASHVERSION
    log_info "No input dashbase version, use default version $DASHVERSION"
  else
    log_info "Dashbase version entered is $VERSION"
    if [ "$(curl --silent -k https://registry.hub.docker.com/v2/repositories/dashbase/api/tags/$VERSION |tr -s ',' '\n' |grep -c digest)" -eq 1 ]; then
      log_info "Entered dashbase version $VERSION is valid"
    else
      log_fatal "Entered dashbase version $VERSION is invalid"
    fi
  fi
}

check_ostype() {
  if [[ $OSTYPE == *"darwin"* ]]; then
    log_info "Dedected current workstation OS is mac"
  elif [[ $OSTYPE == *"linux"* ]]; then
    #log_info "Dedected current workstation is a linux"
    LINUXTYPE=$(cat /etc/os-release |grep NAME |grep -iv "_" |sed 's/\"//g' |cut -d "=" -f2 |awk '{print $1}')
    if [ "$LINUXTYPE" ==  "CentOS" ]; then
      log_info "Dedected current workstation OS is centos"
    elif [ "$LINUXTYPE" ==  "Ubuntu" ]; then
      log_info "Dedected current workstation OS is ubuntu"
    fi
  else
    log_warning "Dedected current workstation OS is neither mac, centos, ubuntu"
  fi
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
  if [ "$BASIC_AUTH" == "true" ] && [ "$INGRESS_FLAG" != "true" ]; then
    log_fatal "Basic auth is selected but not selecting --ingress for installer script"
  elif [ "$BASIC_AUTH" == "true" ] && [ -z "$SUBDOMAIN" ]; then
    log_fatal "Basic auth is selected but not providing --subdomain=sub.example.com string for installer script"
  fi
}

check_v2() {
  # check v2 input
  if [ "$V2_FLAG" ==  "true" ] && [ "$BUCKETNAME" == "undefined" ]; then
    log_fatal "V2 is selected but not provide any cloud object storage bucket name"
  elif [ "$V2_FLAG" ==  "true" ] &&  [ "$BUCKETNAME" != "undefined" ]; then
    log_info "V2 is selected and bucket name is $BUCKETNAME"
  elif [ "$V2_FLAG" ==  "true" ] && [ "$PLATFORM" == "gce" ]; then
    log_info "V2 is selected and cloud platform is gce"
    if [ "$STORAGE_ACCOUNT" == "undefined" ] || [ "$STORAGE_KEY" == "undefined" ]; then
      log_fatal "V2 setup on GCE requires inputs for --storage_account and --storage_key"
    fi
  elif [ "$V2_FLAG" ==  "true" ] && [ "$PLATFORM" == "azure" ]; then
    log_info "V2 is selected and cloud platform is azure"
    if [ "$STORAGE_ACCOUNT" == "undefined" ] || [ "$STORAGE_KEY" == "undefined" ]; then
      log_fatal "V2 setup on Azure requires inputs for --storage_account and --storage_key"
    fi
  elif [ "$V2_FLAG" ==  "false" ]; then
    log_info "V2 is not selected in this installation"
  fi
}

preflight_check() {
  # preflight checks
  log_info "OS type running this script is $OSTYPE"
  CMDS="kubectl curl"
  for x in $CMDS; do
    command -v "$x" >/dev/null && continue || {
      log_fatal "This script requires $x command and is not found."
    }
  done

  # check kubernetes API server is connectable
  if ! kubectl cluster-info &>/dev/null; then
    log_fatal "Failed to connect your Kubernetes API server, please check your config or network."
  fi

  check_k8s_permission

  echo ""
  echo "Checking kubernetes nodes capacity..."
  AVAIILABLE_NODES=0
  # get comma separated nodes info
  # gke-chao-debug-default-pool-a5df0776-588v,3920m,12699052Ki
  for NODE_INFO in $(kubectl get node -o jsonpath='{range .items[*]}{.metadata.name},{.status.capacity.cpu},{.status.capacity.memory}{"\n"}{end}'); do
    # replace comma with spaces.
    read -r NODE_NAME NODE_CPU NODE_MEMORY <<<"$(echo "$NODE_INFO" | tr ',' ' ')"
    check_node "$NODE_NAME" "$NODE_CPU" "$NODE_MEMORY"
  done
  echo ""
  if [ $AVAIILABLE_NODES -ge 2 ]; then
    log_info "This cluster is ready for dashbase installation on resources"
  else
    log_fatal "This cluster doesn't have enough resources for dashbase installation(3 nodes with each have 8 core and 64 Gi at least)."
  fi
}

adminpod_setup() {
  # create namespace dashbase and admin service account for installation
  if [ "$(kubectl get namespace | grep -c dashbase)" -gt 0 ]; then
    log_warning "Previous dashbase namespace exists"
  else
    kubectl create namespace dashbase
  fi
  if [ "$(kubectl get sa -n dashbase | grep -c dashadmin)" -gt 0 ]; then
    log_warning "Previous service account dashadmin exists in dashbase namespace"
  else
    kubectl create serviceaccount dashadmin -n dashbase
  fi
  if [ "$(kubectl get clusterrolebindings | grep -c admin-user-binding)" -gt 0 ]; then
    log_warning "Previous cluster role binding admin-user-binding exists"
  else
    kubectl create clusterrolebinding admin-user-binding --clusterrole=cluster-admin --serviceaccount=dashbase:dashadmin
  fi
  if [ "$(kubectl get po -n dashbase | grep -c admindash)" -gt 0 ]; then
    log_fatal "Previous admin pod admindash exists"
  else
    # Download and install installer helper statefulset yaml file
    curl -k https://raw.githubusercontent.com/dashbase/dashbase-installation/master/deployment-tools/config/admindash-sts_helm3.yaml -o admindash-sts_helm3.yaml
    kubectl apply -f admindash-sts_helm3.yaml -n dashbase
    log_info "setting up admin pod, please wait for three minutes"
    kubectl wait --for=condition=Ready pods/admindash-0 --timeout=180s -n dashbase
    # Check to ensure admin pod is available else exit 1
    APODSTATUS=$(kubectl wait --for=condition=Ready pods/admindash-0 -n dashbase | grep -c "condition met")
    if [ "$APODSTATUS" -eq "1" ]; then echo "Admin Pod is available"; else log_fatal "Admin Pod  admindash-0 is not available"; fi
  fi
}

setup_helm_tiller() {
  # create tiller service account in kube-system namespace
  kubectl exec -it admindash-0 -n dashbase -- bash -c "wget -O /data/rbac-config.yaml https://raw.githubusercontent.com/dashbase/dashbase-installation/master/deployment-tools/config/rbac-config.yaml"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl apply -f /data/rbac-config.yaml"
  # start tiller
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm init --service-account tiller"
  kubectl wait --for=condition=Available deployment/tiller-deploy -n kube-system
  # check helm
  # adding dashbase helm repo
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm repo add dashbase https://charts.dashbase.io"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm repo list"
}

check_helm() {
  # check helm
  # adding dashbase helm repo
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm repo add dashbase https://charts.dashbase.io"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm repo add stable https://kubernetes-charts.storage.googleapis.com"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm repo update"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm repo list"
}

create_storageclass() {
  # create storageclass
  if [ "$PLATFORM" == "aws" ]; then
    log_info "create storageclass for AWS disk"
    kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl apply -f /data/dashbase-data-aws.yaml -n dashbase"
    kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl apply -f /data/dashbase-meta-aws.yaml -n dashbase"
    kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl apply -f /data/dashbase-indexer-aws.yaml -n dashbase"

  elif [ "$PLATFORM" == "gce" ]; then
    log_info "create storageclass for GCE disk"
    kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl apply -f /data/dashbase-data-gce.yaml -n dashbase"
    kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl apply -f /data/dashbase-meta-gce.yaml -n dashbase"
    kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl apply -f /data/dashbase-indexer-gce.yaml -n dashbase"
  elif [ "$PLATFORM" == "azure" ]; then
    log_info "create storageclass for Azure disk"
    kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl apply -f /data/dashbase-data-azure.yaml -n dashbase"
    kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl apply -f /data/dashbase-indexer-azure.yaml -n dashbase"
  fi
  kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl get storageclass |grep dashbase"
  STORECLASSCHK=$(kubectl get storageclass | grep -c dashbase)
  if [ "$STORECLASSCHK" -eq "3" ]; then echo "Dashbase storageclasses are available"; else log_fatal "Dashbase storageclasses not found"; fi
}

download_dashbase() {
  # download and update the dashbase helm value yaml files
  log_info "Downloading dashbase setup tar file from Github"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "wget -O /data/dashbase_setup_nolicy.tar  https://github.com/dashbase/dashbase-installation/raw/master/deployment-tools/dashbase-admin/dashbase_setup_tarball/dashbase_setup_nolicy.tar"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "tar -xvf /data/dashbase_setup_nolicy.tar -C /data/"
  # get the custom values yaml file
  if [ "$V2_FLAG" == "true" ]; then
    log_info "Download dashbase-values-v2.yaml file for v2 setup"
    kubectl exec -it admindash-0 -n dashbase -- bash -c "wget -O /data/dashbase-values.yaml https://github.com/dashbase/dashbase-installation/raw/master/deployment-tools/dashbase-admin/dashbase_setup_tarball/largesetup/dashbase-values-v2.yaml"
  else
    log_info "Download dashbase-values.yaml file for v1 setup"
    kubectl exec -it admindash-0 -n dashbase -- bash -c "wget -O /data/dashbase-values.yaml https://github.com/dashbase/dashbase-installation/raw/master/deployment-tools/dashbase-admin/dashbase_setup_tarball/largesetup/dashbase-values.yaml"
  fi

  kubectl exec -it admindash-0 -n dashbase -- bash -c "chmod a+x /data/*.sh"
  # create sym link for dashbase custom values yaml from /dashbase
  kubectl exec -it admindash-0 -n dashbase -- bash -c "ln -s /data/dashbase-values.yaml  /dashbase/dashbase-values.yaml"
}

update_dashbase_valuefile() {
  # update dashbase-values.yaml for platform choice and subdomain
  if [ -n "$SUBDOMAIN" ]; then
    log_info "update ingress subdomain in dashbase-values.yaml file"
    kubectl exec -it admindash-0 -n dashbase -- bash -c "sed -i 's|test.dashbase.io|$SUBDOMAIN|' /data/dashbase-values.yaml"
  elif [ -z "$SUBDOMAIN" ]; then
    log_info "no input on --subdomain will use default which is test.dashbase.io"
  fi
  # update platform type in dashbase-values.yaml file
  if [ "$PLATFORM" == "aws" ]; then
    log_info "use default platform type aws in dashbase-values.yaml"
  elif [ "$PLATFORM" == "gce" ]; then
    log_info "update platform type gce in dashbase-values.yaml"
    kubectl exec -it admindash-0 -n dashbase -- sed -i 's/aws/gce/' /data/dashbase-values.yaml
  elif [ "$PLATFORM" == "azure" ]; then
    log_info "update platform type azure in dashbase-values.yaml"
    kubectl exec -it admindash-0 -n dashbase -- sed -i 's/aws/azure/' /data/dashbase-values.yaml
  fi
  # update dashbase license information
  if [[ "$USERNAME" == "undefined" && "$LICENSE" == "undefined" ]]; then
    USERNAME="dashuser"
    log_warning "No License information is entered, install default 60 days trial license"
    kubectl exec -it admindash-0 -n dashbase -- wget -q https://dashbase-public.s3-us-west-1.amazonaws.com/lapp/dash-lapp-1.0.0-rc9.jar -O dash-lapp-1.0.0-rc9.jar
    kubectl exec -it admindash-0 -n dashbase -- bash -c "/usr/bin/java -jar dash-lapp-1.0.0-rc9.jar -u $USERNAME -d 60 > 60dlicensestring"
    LICENSE=$(kubectl exec -it admindash-0 -n dashbase -- cat 60dlicensestring)
    echo "username: \"$USERNAME\"" > dashbase-license.txt
    echo "license: \"$LICENSE\"" >> dashbase-license.txt
    kubectl cp dashbase-license.txt dashbase/admindash-0:/data/
    kubectl exec -it admindash-0 -n dashbase -- bash -c "cat /data/dashbase-license.txt >> /data/dashbase-values.yaml"
    kubectl exec -it admindash-0 -n dashbase -- bash -c "rm -rf dash-lapp-1.0.0-rc9.jar"
  else
    log_info "update default dashbase-values.yaml file with entered license information"
    echo "username: \"$USERNAME\"" > dashbase-license.txt
    echo "license: \"$LICENSE\"" >> dashbase-license.txt
    kubectl cp dashbase-license.txt dashbase/admindash-0:/data/
    kubectl exec -it admindash-0 -n dashbase -- bash -c "cat /data/dashbase-license.txt >> /data/dashbase-values.yaml"
  fi
  # update dashbase version
  if [ -z "$VERSION" ]; then
    log_info "use default version $DASHVERSION in dashbase_version on dashbase-values.yaml"
    kubectl exec -it admindash-0 -n dashbase -- sed -i "s|dashbase_version: nightly|dashbase_version: $DASHVERSION|" /data/dashbase-values.yaml
  else
    log_info "use $VERSION in dashbase_version on dashbase-values.yaml"
    kubectl exec -it admindash-0 -n dashbase -- sed -i "s|dashbase_version: nightly|dashbase_version: $VERSION|" /data/dashbase-values.yaml
  fi
  # enabling presto
  if [ "$PRESTO_FLAG" == "true" ]; then
     log_info "enabling presto and updating dashbase-values.yaml file"
     kubectl exec -it admindash-0 -n dashbase -- sed -i '/^presto\:/{n;d}' /data/dashbase-values.yaml
     kubectl exec -it admindash-0 -n dashbase -- sed -i '/^presto\:/a \ \ enabled\:\ true' /data/dashbase-values.yaml
  fi
  # update basic auth
  if [ "$BASIC_AUTH" == "true" ]; then
    log_info "update dashbase-values.yaml file for basic auth"
    kubectl exec -it admindash-0 -n dashbase -- sed -i '/web\:/!b;n;c\ \ \ \ expose\: false' /data/dashbase-values.yaml
  fi
  # update table name
  log_info "update dashbase-values.yaml file with table name = $TABLENAME"
  kubectl exec -it admindash-0 -n dashbase -- sed -i "s|LOGS|$TABLENAME|" /data/dashbase-values.yaml

  # update ucaas feature
  if [ "$UCAAS_FLAG" == "true" ]; then
    log_info "update dashbase-values.yaml file to enable UCAAS features"
    kubectl exec -it admindash-0 -n dashbase -- sed -i '/exporter\:/!b;n;c\ \ \ \ enabled\: true' /data/dashbase-values.yaml
    kubectl exec -it admindash-0 -n dashbase -- sed -i 's/ENABLE_UCAAS\:\ \"false\"/ENABLE_UCAAS\:\ \"true\"/' /data/dashbase-values.yaml
    kubectl exec -it admindash-0 -n dashbase -- sed -i 's/ENABLE_CALL\:\ \"false\"/ENABLE_CALL\:\ \"true\"/' /data/dashbase-values.yaml
    kubectl exec -it admindash-0 -n dashbase -- sed -i 's/ENABLE_INSIGHTS\:\ \"false\"/ENABLE_INSIGHTS\:\ \"true\"/' /data/dashbase-values.yaml
  fi
  # update CDR log data for insight
  if [ "$CDR_FLAG" == "true" ]; then
     log_info "update dashbase-values.yaml file for CDR data in insights page"
     kubectl exec -it admindash-0 -n dashbase -- sed -i 's/INSIGHTS_IS_CDR\:\ \"false\"/INSIGHTS_IS_CDR\:\ \"true\"/' /data/dashbase-values.yaml
  fi
  # update bucket name and storage access
  if [ "$V2_FLAG" == "true" ]; then
    log_info "update object storage bucket name"
    kubectl exec -it admindash-0 -n dashbase -- bash -c "sed -i 's|MYBUCKET|$BUCKETNAME|' /data/dashbase-values.yaml"

    # update storage account and key for aws,gce,azure object storage access
    if [ "$STORAGE_ACCOUNT" != "undefined" ] && [ "$STORAGE_KEY" != "undefined" ]; then
       log_info "update store_access files for cloud object storage access credentials"
       kubectl exec -it admindash-0 -n dashbase -- sed -i "s|STOREACCOUNT|$STORAGE_ACCOUNT|" /data/store_access_1
       kubectl exec -it admindash-0 -n dashbase -- sed -i "s|STOREACCOUNT|$STORAGE_ACCOUNT|" /data/store_access_2
       kubectl exec -it admindash-0 -n dashbase -- sed -i "s|STOREKEY|$STORAGE_KEY|" /data/store_access_1
       kubectl exec -it admindash-0 -n dashbase -- sed -i "s|STOREKEY|$STORAGE_KEY|" /data/store_access_2
       if [ "$PLATFORM" == "azure" ]; then
         log_info "update store_access files with azure blob storage env variables"
         kubectl exec -it admindash-0 -n dashbase -- sed -i "s|AWS_ACCESS_KEY_ID|AZURE_STORAGE_ACCOUNT|" /data/store_access_1
         kubectl exec -it admindash-0 -n dashbase -- sed -i "s|AWS_ACCESS_KEY_ID|AZURE_STORAGE_ACCOUNT|" /data/store_access_2
         kubectl exec -it admindash-0 -n dashbase -- sed -i "s|AWS_SECRET_ACCESS_KEY|AZURE_STORAGE_KEY|" /data/store_access_1
         kubectl exec -it admindash-0 -n dashbase -- sed -i "s|AWS_SECRET_ACCESS_KEY|AZURE_STORAGE_KEY|" /data/store_access_2
       fi
       log_info "update dashbase-values.yaml file with store_access files"
       kubectl exec -it admindash-0 -n dashbase -- sed -i '/searcher\:/ r /data/store_access_1' /data/dashbase-values.yaml
       kubectl exec -it admindash-0 -n dashbase -- sed -i '/table_manager\:/ r /data/store_access_2' /data/dashbase-values.yaml
       kubectl exec -it admindash-0 -n dashbase -- sed -i '/indexer\:/ r /data/store_access_2' /data/dashbase-values.yaml
    fi
    # update V2 bucket mount options for gce
    if [ "$PLATFORM" == "gce" ]; then
      log_info "update dashbase-values.yaml file with google bucket mount options"
      kubectl exec -it admindash-0 -n dashbase -- sed -i '/^\ \ bucket\:/ r /data/gce_mount_options' /data/dashbase-values.yaml
    fi
  fi
  # update keystore passwords for both dashbase and presto
  log_info "update dashbase and presto keystore password in dashbase-values.yaml"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "cd /data ; /data/configure_presto.sh"
}

create_sslcert() {
  # create dashbase SSL cert
  log_info "deploy dashbase with secure connection internally"
  log_info "creating dashbase internal SSL cert, key, keystore, keystore password"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "cd /data ; /data/https_dashbase.sh"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl apply -f  /data/https-dashbase.yaml -n dashbase"
  kubectl get secrets -n dashbase | grep -E 'dashbase-cert|dashbase-key'
  CHKDSECRETS=$(kubectl get secrets -n dashbase | grep -E -c 'dashbase-cert|dashbase-key')
  if [ "$CHKDSECRETS" -eq "4" ]; then
    log_info "dashbase SSL cert, key, keystore and keystore password are created"
  else
    log_fatal "Error to create dashbase SSL cert, key, keystore, and keystore password"
  fi

  # create presto SSL cert
  log_info "setup presto internal SSL cert, key, keystore, keystore password"
  #kubectl exec -it admindash-0 -n dashbase -- bash -c "chmod a+x /data/https_presto2.sh"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "cd /data ; /data/https_presto2.sh"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl apply -f /data/https-presto.yaml -n dashbase"
  kubectl get secrets -n dashbase | grep -E 'presto-cert|presto-key'
  CHKPSECRETS=$(kubectl get secrets -n dashbase | grep -c 'presto')
  if [ "$CHKPSECRETS" -eq "4" ]; then
    log_info "presto SSL cert, key, keystore and keystore password are created"
  else
    log_fatal "Error to create presto SSL cert, key, keystore, and keystore password"
  fi
}

create_basic_auth_secret() {
  log_info "create basic auth secret in admin pod"
  kubectl exec -it admindash-0 -n dashbase -- htpasswd -b -c /data/auth "$AUTHUSERNAME" "$AUTHPASSWORD"
  kubectl exec -it admindash-0 -n dashbase -- kubectl create secret generic dashbase-auth --from-file=/data/auth -n dashbase
  kubectl get secret dashbase-auth -n dashbase
}

install_dashbase() {
  DASHVALUEFILE=$(echo $VALUEFILE | rev | cut -d"/" -f1 | rev)
  log_info "the filename for dashbase value yaml file is $DASHVALUEFILE"
  log_info "Dashbase version $VERSION  and chart version $VERSION is going to install on the target K8s cluster"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm repo update"
  kubectl exec -it admindash-0 -n dashbase -- bash -c "helm install dashbase dashbase/dashbase -f /data/$DASHVALUEFILE --namespace dashbase --version $VERSION --debug --no-hooks > /dev/null"
  echo ""
  echo "please wait a few minutes for all dashbase resources be ready"
  echo ""
  sleep 120 &
  show_spinner "$!"
  # check dashbase deployed resources success or not
  kubectl exec -it admindash-0 -n dashbase -- bash -c "/data/check-dashbase-deploy.sh > >(tee check-dashbase-deploy-output.txt) 2>&1"
  CHKDEPLOYNUM=$(kubectl exec -it admindash-0 -n dashbase -- cat check-dashbase-deploy-output.txt | grep -iv -c Checking)
  CHKSUCCEDNUM=$(kubectl exec -it admindash-0 -n dashbase -- cat check-dashbase-deploy-output.txt | grep -c met)
  if [ "$CHKDEPLOYNUM" -eq "$CHKSUCCEDNUM" ]; then log_info "dashbase installation is completed"; else log_fatal "dashbase installation is failed"; fi
}

# Expose endpoints via Ingress or LoadBalancer
expose_endpoints() {
  if [ "$INGRESS_FLAG" == "true" ]; then
    log_info "setup ngnix ingress controller to expose service "
    kubectl exec -it admindash-0 -n dashbase -- bash -c "helm install nginx-ingress stable/nginx-ingress --namespace dashbase"
    kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl get po -n dashbase |grep ingress"
    # get the exposed IP address from nginx ingress controller
    EXTERNAL_IP=$(kubectl exec -it admindash-0 -n dashbase -- kubectl get svc nginx-ingress-controller -n dashbase | tail -n +2 | awk '{ print $4}')
    log_info "the exposed IP address for web and tables endpoint is $EXTERNAL_IP"
    # Add basic auth ingress
    if [ "$BASIC_AUTH" == "true" ]; then
      log_info "Creating ingress for web with basic auth"
      create_basic_auth_secret
      # update ingress-web.yaml with subdomain name
      kubectl exec -it admindash-0 -n dashbase -- bash -c "sed -i 's|test.dashbase.io|$SUBDOMAIN|' /data/ingress-web.yaml"
      # apply the ingress-web.yaml into K8s cluster
      kubectl exec -it admindash-0 -n dashbase -- bash -c "kubectl apply -f /data/ingress-web.yaml -n dashbase"
    fi
  else
    log_info "setup LoadBalancer with https endpoints to expose services"
    kubectl exec -it admindash-0 -n dashbase -- bash -c "/data/create-lb.sh --https $EXPOSEMON"
  fi
}

# main processes executed below this line
# pre-installation checks

{
check_platform_input
check_ingress_subdomain
check_basic_auth
check_version
check_license
check_v2
preflight_check

# install admin pod
log_info "setup adminpod"
adminpod_setup
download_dashbase

# setup storageclass
if [ "$(kubectl get storageclass -n dashbase | grep -c dashbase)" -gt "0" ]; then
  log_warning "previous dashbase storageclass exists"
  if [ "$(kubectl get pv -n dashbase | grep -c dashbase-)" -gt "0" ]; then
    log_fatal "previous dashbase persistent volumes are detected in this cluster"
  fi
else
  echo "creating dashbase storageclass"
  create_storageclass
fi

check_helm
create_sslcert

# setup dashbase value yaml file and install dashbase
if [ "$VALUEFILE" == "dashbase-values.yaml" ]; then
  log_info "dashbase value yaml file is using default $VALUEFILE"
  update_dashbase_valuefile
  install_dashbase
else
  log_info "using custom dashbase value file $VALUEFILE"
  kubectl cp "$VALUEFILE" dashbase/admindash-0:/data/
  install_dashbase
fi

# expose services
expose_endpoints

# display endpoints
echo "Exposed endpoints are below"

if [[ "$INGRESS_FLAG" == "true"  ]]; then
   echo ""
   echo "Update your DNS server with the following ingress controller IP to map with this name *.$SUBDOMAIN"
   kubectl get svc -n dashbase |grep nginx-ingress-controller |awk '{print $1 "    " $4}'
   echo "Access to dashbase web UI with https://web.$SUBDOMAIN"
   echo "Access to dashbase table endpoint with https://table-logs.$SUBDOMAIN"
   echo "Access to dashbase grafana endpoint with https://grafana.$SUBDOMAIN"
   echo ""
else

  for SERVICE_INFO in $(kubectl get service -o=jsonpath='{range .items[*]}{.metadata.name},{.spec.type},{.status.loadBalancer.ingress[0].ip},{.status.loadBalancer.ingress[0].hostname}{"\n"}{end}' -n dashbase |grep -iv -E 'prometheus|pushgateway'); do
  read -r SERVICE_NAME SERVICE_TYPE SERVICE_LB_IP SERVICE_LB_HOSTNAME <<<"$(echo "$SERVICE_INFO" | tr ',' ' ')"
  if [ "$SERVICE_TYPE" != "LoadBalancer" ]; then
    continue
  fi
  # ingress is one of the loadbalancer, skip here to make the logic clear.
  if [ "$SERVICE_NAME" == "ingress-nginx-ingress-controller" ]; then
    continue
  fi

  if [[ -n "$SERVICE_LB_IP" ]]; then
    echo "LoadBalancer($SERVICE_NAME): IP is ready and is https://$SERVICE_LB_IP"
  elif [[ -n "$SERVICE_LB_HOSTNAME" ]]; then
    echo "LoadBalancer($SERVICE_NAME): IP is ready and is https://$SERVICE_LB_HOSTNAME"
  else
    echo "LoadBalancer($SERVICE_NAME): IP is not ready."
  fi
  done
  
  for SERVICE_INFO in $(kubectl get service -o=jsonpath='{range .items[*]}{.metadata.name},{.spec.type},{.status.loadBalancer.ingress[0].ip},{.status.loadBalancer.ingress[0].hostname}{"\n"}{end}' -n dashbase |grep -E 'prometheus|pushgateway'); do
  read -r SERVICE_NAME SERVICE_TYPE SERVICE_LB_IP SERVICE_LB_HOSTNAME <<<"$(echo "$SERVICE_INFO" | tr ',' ' ')"
  if [ "$SERVICE_TYPE" != "LoadBalancer" ]; then
     continue
  fi
  if [[ -n "$SERVICE_LB_IP" ]]; then
     echo "LoadBalancer($SERVICE_NAME): IP is ready and is http://$SERVICE_LB_IP"
  elif [[ -n "$SERVICE_LB_HOSTNAME" ]]; then
     echo "LoadBalancer($SERVICE_NAME): IP is ready and is http://$SERVICE_LB_HOSTNAME"
  fi
  done

fi

} 2>&1 | tee -a /tmp/dashbase_install_"$(date +%d-%m-%Y_%H-%M-%S)".log
