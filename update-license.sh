
function log_info() {
  echo -e "INFO *** $*"
}

function log_warning() {
  echo -e "WARN *** $*"
}

function log_fatal() {
  echo -e "FATAL *** $*"
  rm -rf ./dashbase-license.txt
  exit 1
}

log_info "Cleaning old license of dashbase-values.yaml "
sed -i '/^username:/d;/^license:/d' /data/dashbase-values.yaml
log_info "Apply license into dashbase-values.yaml"
cat dashbase-license.txt >> /data/dashbase-values.yaml
log_info "helm upgrade dashbase chartmuseum/dashbase -f /data/dashbase-values.yaml --namespace dashbase --devel"
helm upgrade dashbase dashbase/dashbase -f /data/dashbase-values.yaml --namespace dashbase --devel

# Update dashbase license information
log_info "kubectl delete pod $(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase"
kubectl delete pod $(kubectl get pod -n dashbase | grep api | awk '{print $1}') -n dashbase

log_info "kubectl wait --timeout=180s --for=condition=available deployment/api -n dashbase"
kubectl wait --timeout=180s --for=condition=available deployment/api -n dashbase

