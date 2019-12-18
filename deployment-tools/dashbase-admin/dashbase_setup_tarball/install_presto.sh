#!/bin/bash

# Install  Presto
[ -e values-presto.yaml ] && rm -rf values-presto.yaml

kubectl get secrets presto-keystore-password -n dashbase -o yaml |grep "keystore_password:" |awk '{ print $2}' |base64 --decode > presto-keypass
kubectl get secrets dashbase-keystore-password -n dashbase -o yaml |grep "keystore_password:" |awk '{ print $2}' |base64 --decode > dashbase-keypass
PKEYPASS=$(cat presto-keypass)
DASHPASS=$(cat dashbase-keypass)

echo "the dashbase keystore password = $DASHPASS"
echo "the presto keystore password = $PKEYPASS"

cp values-presto-template.yaml  values-presto.yaml

sed -i "s|NAMESPACE|dashbase|" values-presto.yaml
sed -i "s|PRESTO_KEYSTORE_PASSWORD|${PKEYPASS}|" values-presto.yaml
sed -i "s|DASHBASE_KEYSTORE_PASSWORD|${DASHPASS}|" values-presto.yaml

echo "the values-presto.yaml file is created"
echo "helm install --name presto --namespace dashbase --values values-presto.yaml wiwdata-presto-11-single.tgz"
helm install --name presto --namespace dashbase --values values-presto.yaml wiwdata-presto-11-single.tgz
