#!/usr/bin/env bash
set -e

# check kubernetes API server is connectable
if ! kubectl cluster-info &>/dev/null; then
  echo "Failed to connect your Kubernetes API server, please check your config or network."
  exit 1
fi

# check permission
## permissions required by dashbase charts
echo "Checking your RBAC permission:"

echo -n "Admin permission in namespace dashbase: "
kubectl auth can-i '*' '*' -n dashbase

echo -n "Admin permission on namespaces: "
kubectl auth can-i '*' namespaces --all-namespaces

echo -n "Admin permission on nodes: "
kubectl auth can-i '*' nodes --all-namespaces

echo -n "Admin permission on storageclasses: "
kubectl auth can-i '*' storageclasses --all-namespaces

echo -n "Admin permission on persistentvolumes: "
kubectl auth can-i '*' persistentvolumes --all-namespaces

echo -n "Admin permission on clusterroles: "
kubectl auth can-i '*' clusterroles --all-namespaces

echo -n "Admin permission on clusterrolebindings: "
kubectl auth can-i '*' clusterrolebindings --all-namespaces

echo -n "Admin permission on priorityclasses: "
kubectl auth can-i '*' priorityclasses --all-namespaces

## permission required by helm
echo -n "Admin permission in namespace kube-system(required by helm): "
kubectl auth can-i '*' '*' -n kubes-system

## check nodes resources
function check_node_cpu() {
  if [[ "$2" =~ ^([0-9]+)m$ ]]; then
    if [[ ${BASH_REMATCH[1]} -ge 7600 ]]; then
      return 0
    fi
  elif [[ "$2" =~ ^([0-9]+)$ ]]; then
    if [[ ${BASH_REMATCH[1]} -ge 8 ]]; then
      return 0
    fi
  else
    echo "Can't determine the cpu($2) of node($1)."
  fi
  return 1
}

function check_node_memory() {
  if [[ "$2" =~ ^([0-9]+)Ki?$ ]]; then
    if [[ ${BASH_REMATCH[1]} -ge 30000000 ]]; then
      return 0
    fi
  elif [[ "$2" =~ ^([0-9]+)Mi?$ ]]; then
    if [[ ${BASH_REMATCH[1]} -ge 30000 ]]; then
      return 0
    fi
  elif [[ "$2" =~ ^([0-9]+)Gi?$ ]]; then
    if [[ ${BASH_REMATCH[1]} -ge 30 ]]; then
      return 0
    fi
  else
    echo "Can't determine the memory($2) of node($1)."
  fi

  return 1
}

function check_node() {
  if ! check_node_cpu "$1" "$2"; then
    echo "Node($1) doesn't have enough cpu resources(8 core at least)."
    return 0
  fi

  if ! check_node_memory "$1" "$3"; then
    echo "Node($1) doesn't have enough memory resources(32Gi at least)."
    return 0
  fi

  ((AVAIILABLE_NODES++))
  return 0
}

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
  echo "This cluster is ready for dashbase installation on resources"
else
  echo "This cluster doesn't have enough resources for dashbase installation(2 nodes with each have 8 core and 32 Gi at least)."
fi
