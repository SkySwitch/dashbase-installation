#!/bin/bash

# Configure  Dashbase Presto Saml keystore passwords in dashbase-values.yaml file

kubectl get secrets presto-keystore-password -n dashbase -o yaml |grep "keystore_password:" |awk '{ print $2}' |base64 --decode > presto-keypass
kubectl get secrets dashbase-keystore-password -n dashbase -o yaml |grep "keystore_password:" |awk '{ print $2}' |base64 --decode > dashbase-keypass
kubectl get secrets saml-keystore-password -n dashbase -o yaml |grep "keystore_password:" |awk '{ print $2}' |base64 --decode > saml-keypass
PKEYPASS=$(cat presto-keypass)
DASHPASS=$(cat dashbase-keypass)
SAMLPASS=$(cat saml-keypass)

echo "the dashbase keystore password = $DASHPASS"
echo "the presto keystore password = $PKEYPASS"
echo "the saml keystore password = $SAMLPASS"

sed -i "s|PRESTO_KEYSTORE_PASSWORD|${PKEYPASS}|" /data/dashbase-values.yaml
sed -i "s|DASHBASE_KEYSTORE_PASSWORD|${DASHPASS}|" /data/dashbase-values.yaml
sed -i "s|SAMLKEYPASS|${SAMLPASS}|" /data/dashbase-values.yaml

echo "the dashbase-values.yaml file is updated with dashbase presto and saml keystore password"
