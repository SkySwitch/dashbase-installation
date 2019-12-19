#!/bin/bash

# Configure  Presto keystore passwords in dashbase-values.yaml file

kubectl get secrets presto-keystore-password -n dashbase -o yaml |grep "keystore_password:" |awk '{ print $2}' |base64 --decode > presto-keypass
kubectl get secrets dashbase-keystore-password -n dashbase -o yaml |grep "keystore_password:" |awk '{ print $2}' |base64 --decode > dashbase-keypass
PKEYPASS=$(cat presto-keypass)
DASHPASS=$(cat dashbase-keypass)

echo "the dashbase keystore password = $DASHPASS"
echo "the presto keystore password = $PKEYPASS"

sed -i "s|PRESTO_KEYSTORE_PASSWORD|${PKEYPASS}|" dashbase-values.yaml
sed -i "s|DASHBASE_KEYSTORE_PASSWORD|${DASHPASS}|" dashbase-values.yaml

echo "the dashbase-values.yaml file is updated with dashbase and presto keystore password"
