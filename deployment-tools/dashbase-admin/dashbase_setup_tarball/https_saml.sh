#!/bin/bash
# This script will nstall secure dashbase in k8s  and also will setup redash.
# run the script example
# ./https_saml.sh <namespace>

# enter namespace value, not entering namespace value will auto exit
if [ -z "$1" ]
then
   echo "no namespace entered"
   echo "will use default namespace = dashbase"
   NAMESPACE="dashbase"
else
   echo "entered namespace value = $1"
   NAMESPACE=$1
fi

# remove previous saml cert, key and keystore in the current folder
[ -e saml-keystore ] && rm -rf saml-keystore
[ -e saml-keystore.p12 ] && rm -rf saml-keystore.p12
[ -e saml-cert.pem ] && rm -rf saml-cert.pem
[ -e saml-key.pem ] && rm -rf saml-key.pem
[ -e saml_keystore_password ] && rm -rf saml_keystore_password
[ -e https-saml.yaml ] && rm -rf https-saml.yaml

# bash generate random 32 character alphanumeric string (upper and lowercase) and

export LC_CTYPE=C

KEYSTORE_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
#NAMESPACE=$1
#echo "entered namespace is $NAMESPACE"
echo $KEYSTORE_PASS > saml_keystore_password
KEYSTORE_PASSWORD=$(cat saml_keystore_password)
echo "Creating saml-keystore file"

keytool -genkey -noprompt \
 -alias saml \
 -dname "CN=dashbase.io, OU=Engineering, O=Dashbase, L=Santa clara, S=CA, C=US" \
 -keystore saml-keystore \
 -storepass $KEYSTORE_PASSWORD \
 -keypass $KEYSTORE_PASSWORD \
 -keyalg RSA  \
 -validity 3650 \
 -keysize 2048

echo "Convert dashbase-keystore into p12 format and output is dashbase-keystore.p12 file"
keytool -importkeystore -srckeystore saml-keystore \
  -destkeystore saml-keystore.p12 -deststoretype PKCS12 \
  -deststorepass $KEYSTORE_PASSWORD -srcstorepass $KEYSTORE_PASSWORD


echo "using openssl command creating dashbase-cert.pem  and  dashbase-key.pem  file from dashbase-keystore.p12"
openssl pkcs12 -in saml-keystore.p12 -nokeys -out saml-cert.pem -passin pass:$KEYSTORE_PASSWORD
openssl pkcs12 -in saml-keystore.p12 -nodes -nocerts -out saml-key.pem -passin pass:$KEYSTORE_PASSWORD

echo "signed signed-cert generation for saml is completed"
echo "you should have the following files:"
echo "1. saml-kestore  java keystore for dashbase"
echo "2. saml-keystore.p12 P12 format file for dashbase-keystore"
echo "3. saml-cert.pem base 64 cert file for dashbase"
echo "4. saml-key.pem  base 64 key file for dashbase"
echo "The CN of this self-signed cert is dashbase.io"

# create Base 64 encryption for generated key, cert, keystore, keystore password

if [[ "$OSTYPE" == "darwin"* ]]; then
   echo "create dashbase Base 64 encryption for generated key, cert, keystore, keystore password from mac workstation"
   SAML_KEYSTORE_PASS_B64=`echo -n "$KEYSTORE_PASSWORD" |base64`
   SAML_KEYSTORE_B64=`cat saml-keystore |base64`
   SAML_CERT_B64=`cat saml-cert.pem |base64`
   SAML_KEY_B64=`cat saml-key.pem |base64`
elif [[ "$OSTYPE" == "linux-gnu" ]] || [[ "$OSTYPE" == "linux-musl" ]]; then
   echo "create dashbase Base 64 encryption for generated key, cert, keystore, keystore password from linux workstation"
   SAML_KEYSTORE_PASS_B64=`echo -n "$KEYSTORE_PASSWORD" |base64 -w 0`
   SAML_KEYSTORE_B64=`cat saml-keystore |base64 -w 0`
   SAML_CERT_B64=`cat saml-cert.pem |base64 -w 0`
   SAML_KEY_B64=`cat saml-key.pem |base64 -w 0`
else
   echo "OSTYPE is not supported"
   exit
fi

#echo "Presto keystore password"
#echo $DASHBASE_KEYSTORE_PASS_B64
#echo "####################################################"
#echo "dashbase keystore"
#echo $DASHBASE_KEYSTORE_B64
#echo "####################################################"
#echo "dashbase cert"
#echo $DASHBASE_CERT_B64
#echo "####################################################"
#echo "dashbase key"
#echo $DASHBASE_KEY_B64
#echo "####################################################"

# feed the base64 outputs of key, cert, keystore, and keystore password into https-dashbase.yaml file

echo "feed the base64 outputs of key, cert, keystore, and keystore password into https-saml.yaml file"
cp https-saml-template.yaml https-saml.yaml


if [[ "$OSTYPE" == "darwin"* ]]; then
   sed -i .bak "s|KEYSTORE|${SAML_KEYSTORE_B64}|" https-saml.yaml
   sed -i .bak "s|KEYPASS|${SAML_KEYSTORE_PASS_B64}|" https-saml.yaml
   sed -i .bak "s|CERTPEM|${SAML_CERT_B64}|" https-saml.yaml
   sed -i .bak "s|KEYPEM|${SAML_KEY_B64}|" https-saml.yaml
elif [[ "$OSTYPE" == "linux-gnu" ]] || [[ "$OSTYPE" == "linux-musl" ]]; then
   sed -i "s|KEYSTORE|${SAML_KEYSTORE_B64}|" https-saml.yaml
   sed -i "s|KEYPASS|${SAML_KEYSTORE_PASS_B64}|" https-saml.yaml
   sed -i "s|CERTPEM|${SAML_CERT_B64}|" https-saml.yaml
   sed -i "s|KEYPEM|${SAML_KEY_B64}|" https-saml.yaml
else
   echo "OSTYPE is not supported"
   exit
fi

echo "https-saml.yaml file is updated"
echo "kubectl apply -f https-saml.yaml -n $NAMESPACE"
#kubectl apply -f https-saml.yaml -n $NAMESPACE
kubectl get secrets -n $NAMESPACE |grep dashbase
echo "install steps for dashbase SSL cert, pem, keystore on K8s cluster is completed"
