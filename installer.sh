#!/bin/bash

curl https://raw.githubusercontent.com/dashbase/dashbase-installation/admin_installer/dashbase-admin.yaml | kubectl apply -f -
echo 'Waiting for dashbase-admin pod to be ready...'
kubectl wait pod/dashbase-admin-0 --for condition=Ready --timeout=2m
echo 'Pod is ready. Running init script...'
kubectl exec -it pod/dashbase-admin-0 ./init.sh
echo 'Done.'