#!/usr/bin/env bash

# required commands
# - jq
# - kubectl

# create tmp dir
mkdir -p generated

for kv in $(jq -c ".kvs[]" etcd-templates-backup.json); do
  KEY=$(jq -r '.key | @base64d' <<<"$kv")
  VALUE=$(jq -r '.value | @base64d' <<<"$kv")

  echo -n $VALUE >generated/"${KEY}".json
  kubectl cp generated/"${KEY}".json etcd-cluster-client-0:/"${KEY}".json
  kubectl exec -it etcd-cluster-client-0 -- sh -c "cat /${KEY}.json | ETCDCTL_API=3 etcdctl put ${KEY}"
done
