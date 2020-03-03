#!/usr/bin/env bash

# check statefulsets
echo "Checking Statefulsets pods..."
for STS_INFO in $(kubectl get statefulsets -o=jsonpath='{range .items[*]}{.metadata.name},{.spec.replicas}{"\n"}{end}' -n dashbase |grep presto); do
  read -r STS_NAME STS_REPLICAS <<<"$(echo "$STS_INFO" | tr ',' ' ')"
  if [ $STS_REPLICAS -lt 1 ]; then
    :
  elif [ $STS_REPLICAS -eq 1 ]; then
    kubectl wait --for=condition=Ready pods/"${STS_NAME}"-0 --timeout=300s -n dashbase
  else
    ((STS_REPLICAS--))
    REPLICAS_SERIES=$(seq -s , 0 "$STS_REPLICAS")
    if [[ "$OSTYPE" == "darwin"* ]]; then
      REPLICAS_SERIES="${REPLICAS_SERIES%?}"
    fi
    REPLICAS_SERIES="{${REPLICAS_SERIES}}"
    kubectl wait --for=condition=Ready pods/"${STS_NAME}"-"${REPLICAS_SERIES}" --timeout=300s -n dashbase
  fi
done

