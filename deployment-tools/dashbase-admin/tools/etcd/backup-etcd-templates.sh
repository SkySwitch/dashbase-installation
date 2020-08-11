#!/usr/bin/env bash

# required commands
# - jq
# - kubectl
# - curl
# - base64

if [ "$(kubectl get po -l app=etcd,etcd_cluster=etcd-cluster -o json | jq '.items | length')" -eq 0 ]; then
  echo "No living ETCD-Operator pod found."
  exit 0
fi

ETCD_OPERATOR_PODNAME=$(kubectl get po -l app=etcd,etcd_cluster=etcd-cluster -o json | jq -r '.items[0].metadata.name')

# https://etcd.io/docs/v3.4.0/learning/api/
ETCD_RANGE_KEY="ZGFzaGJhc2VfdGVtcGxhdGU=" # echo -n "dashbase_template" | base64
ETCD_RANGE_END="ZGFzaGJhc2VfdGVtcGxhdGY=" # echo -n "dashbase_templatf" | base64

kubectl exec -it "${ETCD_OPERATOR_PODNAME}" -- apk add curl --update
kubectl exec -it "${ETCD_OPERATOR_PODNAME}" -- curl -L http://localhost:2379/v3beta/kv/range -X POST -d '{"key": "'$ETCD_RANGE_KEY'","range_end": "'$ETCD_RANGE_END'"}' > etcd-templates-backup.json
