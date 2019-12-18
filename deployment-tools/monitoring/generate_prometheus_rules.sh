#!/bin/bash
# Init environment
BASEDIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"

RULES=$(ls $BASEDIR/prometheus-alerts | grep yml)

case "$1" in
  "generate")
    cp -rf $BASEDIR/prometheus-alerts $BASEDIR/alerts-template
    for filename in $RULES
    do
       alerts_name=$(echo $filename | cut -d . -f1)
       helm template $BASEDIR/alerts-template --set alert_name=$alerts_name --set alert_path=prometheus-alerts/$alerts_name.yml > $BASEDIR/prometheus-operator-rules/$alerts_name.yml
    done
    rm -rf $BASEDIR/alerts-template/prometheus-alerts
    exit 0;
  ;;

  "test")
    if [ `kubectl get PrometheusRule -A  &> /dev/null` $? -ne 0 ]; then
      Applied_PrometheusRule="false"
      echo $Applied_PrometheusRule
      echo "Test should be run with K8S and Prometheus Operator"
      exit 1
    else
      cp -rf $BASEDIR/prometheus-alerts alerts-template
      for filename in $RULES
      do
         alerts_name=$(echo $filename | cut -d . -f1)
         helm template $BASEDIR/alerts-template --set alert_name=$alerts_name --set alert_path=prometheus-alerts/$alerts_name.yml | kubectl create --dry-run=true --validate=true -f -
      done
      rm -rf alerts-template/prometheus-alerts
      exit 0;
    fi
  ;;
  "--help")
    printf -- 'Usage: \n';
    printf -- 'generate -- Generate Prometheus Operator rules.\n';
    printf -- 'test -- Run test for Prometheus Operator rules.\n';
    exit 0;
  ;;
  *)
    echo "Option should be provied, Please use --help for help."
    exit 0;
esac