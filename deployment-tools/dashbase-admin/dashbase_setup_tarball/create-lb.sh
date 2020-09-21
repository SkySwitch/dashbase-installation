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
  echo "Kubernetes service \"web\" is not found, skip to expose dashbase-web."
else
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
fi

# expose tables
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


expose_dashbase_mon() {
# expose grafana service

if kubectl get service grafana-lb -n dashbase &>/dev/null; then                                                                                                  
    echo "LoadBalancer grafana-lb is already existed, skip creation."                                                                                                    
  else                                                                                                                                                                 
    echo "Exposing dashbase monitoring service $MSVCNAME..."                                                                                                           
    kubectl expose service grafana --port=${PORT} --target-port=3000 --name=grafana-lb --type=LoadBalancer -n dashbase                                  
    echo "Waiting kubernetes to ensure LoadBalancer..."                                                                                                                
    SECONDS_WAITED=0                                                                                                                                                   
                                                                                                                                                                       
    while true; do                                                                                                                                                     
      GRAFANA_LB_INFO=$(kubectl get service grafana-lb -o=jsonpath='{.status.loadBalancer.ingress[0].ip},{.status.loadBalancer.ingress[0].hostname}' -n dashbase)     
      read -r GRAFANA_LB_IP GRAFANA_LB_HOSTNAME <<<"$(echo "$GRAFANA_LB_INFO" | tr ',' ' ')"                                                                                    
                                                                                                                                                                       
      if [[ -n "$GRAFANA_LB_IP" ]]; then                                                                                                                                  
        echo "grafana exposed to $SCHEMA://$GRAFANA_LB_IP:$PORT successfully."                                                                                          
        break                                                                                                                                                          
      elif [[ -n "$MSVC_LB_HOSTNAME" ]]; then                                                                                                                          
        echo "grafana exposed to $SCHEMA://$GRAFANA_LB_HOSTNAME:$PORT successfully."                                                                                    
        break                                                                                                                                                          
      fi                                                                                                                                                               
                                                                                                                                                                       
      if [[ $SECONDS_WAITED -ge $LB_CHECK_TIMEOUT ]]; then                                                                                                             
        echo "Warning: Timed out(${LB_CHECK_TIMEOUT}s) waiting LoadBalancer to be ok. Please check the LoadBalancer grafana-lb manually."                            
        break                                                                                                                                                          
      fi                                                                                                                                                               
                                                                                                                                                                       
      echo "Wait another 15 seconds to do a next check."                                                                                                               
      sleep 15                                                                                                                                                         
      ((SECONDS_WAITED = SECONDS_WAITED + 15))                                                                                                                         
   done                                                                                                                                                               
fi                   

# expose pushgateway prometheus and grafana
for MSVC in pushgateway,9091 prometheus,9090; do
  MSVCNAME=$(echo $MSVC |cut -d"," -f1)
  if kubectl get service "$MSVCNAME"-lb -n dashbase &>/dev/null; then
    echo "LoadBalancer $MSVCNAME-lb is already existed, skip creation."
  else
    echo "Exposing dashbase monitoring service $MSVCNAME..."
    MSVCPORT=$(echo $MSVC |cut -d"," -f2)
    kubectl expose service "$MSVCNAME" --port=80 --target-port=${MSVCPORT} --name="$MSVCNAME"-lb --type=LoadBalancer -n dashbase
    echo "Waiting kubernetes to ensure LoadBalancer..."
    SECONDS_WAITED=0

    while true; do
      MSVC_LB_INFO=$(kubectl get service "$MSVCNAME"-lb -o=jsonpath='{.status.loadBalancer.ingress[0].ip},{.status.loadBalancer.ingress[0].hostname}' -n dashbase)
      read -r MSVC_LB_IP MSVC_LB_HOSTNAME <<<"$(echo "$MSVC_LB_INFO" | tr ',' ' ')"

      if [[ -n "$MSVC_LB_IP" ]]; then
        echo "$MSVCNAME exposed to http://$MSVC_LB_IP successfully."
        break
      elif [[ -n "$MSVC_LB_HOSTNAME" ]]; then
        echo "$MSVCNAME exposed to http://$MSVC_LB_HOSTNAME successfully."
        break
      fi

      if [[ $SECONDS_WAITED -ge $LB_CHECK_TIMEOUT ]]; then
        echo "Warning: Timed out(${LB_CHECK_TIMEOUT}s) waiting LoadBalancer to be ok. Please check the LoadBalancer $MSVCNAME-lb manually."
        break
      fi

      echo "Wait another 15 seconds to do a next check."
      sleep 15
      ((SECONDS_WAITED = SECONDS_WAITED + 15))
    done
  fi
done
}

expose_dashbase_admin_server() {
# expose admindash service
if kubectl get service admindash-lb -n dashbase &>/dev/null; then
    echo "LoadBalancer admindash-lb is already existed, skip creation."
  else
    echo "Exposing dashbase monitoring service admindash..."
    kubectl expose service admindash --port=80 --target-port=5000 --name=admindash-lb --type=LoadBalancer -n dashbase
    echo "Waiting kubernetes to ensure LoadBalancer..."
    SECONDS_WAITED=0

    while true; do
      ADMINDASH_LB_INFO=$(kubectl get service admindash-lb -o=jsonpath='{.status.loadBalancer.ingress[0].ip},{.status.loadBalancer.ingress[0].hostname}' -n dashbase)
      read -r ADMINDASH_LB_IP ADMINDASH_LB_HOSTNAME <<<"$(echo "$ADMINDASH_LB_INFO" | tr ',' ' ')"

      if [[ -n "$ADMINDASH_LB_IP" ]]; then
        echo "admindash exposed to http://$ADMINDASH_LB_IP successfully."
        break
      elif [[ -n "$ADMINDASH_LB_HOSTNAME" ]]; then
        echo "admindash exposed to http://$ADMINDASH_LB_HOSTNAME  successfully."
        break
      fi

      if [[ $SECONDS_WAITED -ge $LB_CHECK_TIMEOUT ]]; then
        echo "Warning: Timed out(${LB_CHECK_TIMEOUT}s) waiting LoadBalancer to be ok. Please check the LoadBalancer admindash-lb manually."
        break
      fi

      echo "Wait another 15 seconds to do a next check."
      sleep 15
      ((SECONDS_WAITED = SECONDS_WAITED + 15))
   done
fi
}

if [[ -n $2 && $2 == "--exposemon" ]]; then
   expose_dashbase_mon
fi

# Exposing admin server is by default
expose_dashbase_admin_server
