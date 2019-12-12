#!/usr/bin/env bash
set -e

LB_CHECK_TIMEOUT=300

if [ "$1" == "--http" ]; then
  SCHEMA="http"
  PORT="80"
else
  SCHEMA="https"
  PORT="443"
fi

if ! kubectl get service web -n dashbase &>/dev/null; then
  echo "Kubernetes service \"web\" is not found, Please check your dashbase installation is ok."
  exit 1
fi

# expose web
if kubectl get service web-lb -n dashbase &>/dev/null; then
  echo "LoadBalancer web-lb is already existed, skip creation."
else
  echo "Exposing web..."
  kubectl expose service web --port=${PORT} --target-port=8080 --name=web-lb --type=LoadBalancer -l type=lb -n dashbase
  echo "Waiting kubernetes to ensure LoadBalancer..."
  SECONDS_WAITED=0

  while true; do
    WEB_LB_INFO=$(kubectl get service web-lb -o=jsonpath='{.status.loadBalancer.ingress[0].ip},{.status.loadBalancer.ingress[0].hostname}' -n dashbase)
    read -r WEB_LB_IP WEB_LB_HOSTNAME <<<"$(echo "$WEB_LB_INFO" | tr ',' ' ')"
    if [[ -n "$WEB_LB_IP" ]]; then
      echo "Web exposed to $SCHEMA://$WEB_LB_IP:$PORT successfully."
      break
    elif [[ -n "$WEB_LB_HOSTNAME" ]]; then
      echo "Web exposed to $SCHEMA://$WEB_LB_HOSTNAME:$PORT successfully."
      break
    fi

    if [[ $SECONDS_WAITED -ge $LB_CHECK_TIMEOUT ]]; then
      echo "Warning: Timed out(${LB_CHECK_TIMEOUT}s) waiting LoadBalancer to be ok. Please check the LoadBalancer web-lb manually."
      break
    fi
    echo "Wait another 15 seconds to do a next check."
    sleep 15
    ((SECONDS_WAITED = SECONDS_WAITED + 15))
  done
fi

for SERVICE_INFO in $(kubectl get service -l component=table -o=jsonpath='{range .items[*]}{.metadata.name},{.spec.type}{"\n"}{end}' -n dashbase); do
  read -r SERVICE_NAME SERVICE_TYPE <<<"$(echo "$SERVICE_INFO" | tr ',' ' ')"
  if [ "$SERVICE_TYPE" != "ClusterIP" ]; then
    continue
  fi

  if kubectl get service "$SERVICE_NAME"-lb -n dashbase &>/dev/null; then
    echo "LoadBalancer $SERVICE_NAME-lb is already existed, skip creation."
  else
    echo "Exposing $SERVICE_NAME..."
    kubectl expose service "$SERVICE_NAME" --port=${PORT} --target-port=7888 --name="$SERVICE_NAME"-lb --type=LoadBalancer -n dashbase
    echo "Waiting kubernetes to ensure LoadBalancer..."
    SECONDS_WAITED=0

    while true; do
      TABLE_LB_INFO=$(kubectl get service "$SERVICE_NAME"-lb -o=jsonpath='{.status.loadBalancer.ingress[0].ip},{.status.loadBalancer.ingress[0].hostname}' -n dashbase)
      read -r TABLE_LB_IP TABLE_LB_HOSTNAME <<<"$(echo "$TABLE_LB_INFO" | tr ',' ' ')"

      if [[ -n "$TABLE_LB_IP" ]]; then
        echo "$SERVICE_NAME exposed to $SCHEMA://$TABLE_LB_IP:$PORT successfully."
        break
      elif [[ -n "$TABLE_LB_HOSTNAME" ]]; then
        echo "$SERVICE_NAME exposed to $SCHEMA://$TABLE_LB_HOSTNAME:$PORT successfully."
        break
      fi

      if [[ $SECONDS_WAITED -ge $LB_CHECK_TIMEOUT ]]; then
        echo "Warning: Timed out(${LB_CHECK_TIMEOUT}s) waiting LoadBalancer to be ok. Please check the LoadBalancer $SERVICE_NAME-lb manually."
        break
      fi

      echo "Wait another 15 seconds to do a next check."
      sleep 15
      ((SECONDS_WAITED = SECONDS_WAITED + 15))
    done
  fi
done
