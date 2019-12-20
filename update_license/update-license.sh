
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

function run_catch() {
if [[ $? = 0 ]]; then
  log_info "SUCCESS: $*"
else
  log_fatal "FAILURE: $*"
fi
}

log_info "Cleaning old license of dashbase-values.yaml "
sed -i '/^username:/d;/^license:/d' /data/dashbase-values.yaml
log_info "Update license into dashbase-values.yaml"
cat dashbase-license.txt >> /data/dashbase-values.yaml

# Check chart version

chart_version=$(helm ls '^dashbase$' |grep 'dashbase' |  awk '{print $9}')
APP_version=$(helm ls '^dashbase$' |grep 'dashbase' |  awk '{print $9}')

if [[ $chart_version == "dashbase->0.0.0-0" ]]; then
  helm upgrade dashbase dashbase/dashbase -f /data/dashbase-values.yaml --namespace dashbase --devel &> /dev/null
  run_catch "helm upgrade dashbase chartmuseum/dashbase -f /data/dashbase-values.yaml --namespace dashbase --devel"
else
  helm upgrade dashbase dashbase/dashbase -f /data/dashbase-values.yaml --namespace dashbase --version $APP_version &> /dev/null
  run_catch "helm upgrade dashbase dashbase/dashbase -f /data/dashbase-values.yaml --namespace dashbase --version $APP_version"
fi

# Update dashbase license information
kubectl delete pod $(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase
run_catch "kubectl delete pod $(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase"

kubectl wait --timeout=180s --for=condition=available deployment/api -n dashbase
run_catch "kubectl wait --timeout=180s --for=condition=available deployment/api -n dashbase"

