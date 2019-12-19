# This script will nstall secure presto in k8s  and also will setup redash.
# run the script example
# ./https_presto.sh <namespace>

#!/bin/bash
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

# remove previous presto cert, key and keystore in the current folder
[ -e presto-keystore ] && rm -rf presto-keystore
[ -e presto-keystore.p12 ] && rm -rf presto-keystore.p12
[ -e presto-cert.pem ] && rm -rf presto-cert.pem
[ -e presto-key.pem ] && rm -rf presto-key.pem
[ -e presto_keystore_password ] && rm -rf presto_keystore_password
[ -e https.yaml ] && rm -rf https.yaml

# bash generate random 32 character alphanumeric string (upper and lowercase) and

export LC_CTYPE=C

KEYSTORE_PASS=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 32 | head -n 1)
#NAMESPACE=$1
#echo "entered namespace is $NAMESPACE"
echo $KEYSTORE_PASS > presto_keystore_password
KEYSTORE_PASSWORD=$(cat presto_keystore_password)
echo "Creating presto-keystore file"

keytool -genkey -noprompt \
 -alias dashbase \
 -dname "CN=$NAMESPACE-presto-coordinator-0.$NAMESPACE-presto-coordinator.$NAMESPACE.svc.cluster.local, OU=Engineering, O=Dashbase, L=Santa clara, S=CA, C=US" \
 -keystore presto-keystore \
 -storepass $KEYSTORE_PASSWORD \
 -keypass $KEYSTORE_PASSWORD \
 -keyalg RSA  \
 -validity 3650 \
 -keysize 2048

echo "Convert presto-keystore into p12 format and output is presto-keystore.p12 file"
keytool -importkeystore -srckeystore presto-keystore \
  -destkeystore presto-keystore.p12 -deststoretype PKCS12 \
  -deststorepass $KEYSTORE_PASSWORD -srcstorepass $KEYSTORE_PASSWORD


echo "using openssl command creating presto-cert.pem  and  presto-key.pem  file from presto-keystore.p12"
openssl pkcs12 -in presto-keystore.p12 -nokeys -out presto-cert.pem -passin pass:$KEYSTORE_PASSWORD
openssl pkcs12 -in presto-keystore.p12 -nodes -nocerts -out presto-key.pem -passin pass:$KEYSTORE_PASSWORD

echo "signed signed-cert generation for presto is completed"
echo "you should have the following files:"
echo "1. presto-kestore  java keystore for presto"
echo "2. presto-keystore.p12 P12 format file for presto-keystore"
echo "3. presto-cert.pem base 64 cert file for presto"
echo "4. presto-key.pem  base 64 key file for presto"
echo "The CN of this self-signed cert is $NAMESPACE-presto-coordinator-0.$NAMESPACE-presto-coordinator.$NAMESPACE.svc.cluster.local"

# create Base 64 encryption for generated key, cert, keystore, keystore password

if [[ "$OSTYPE" == "darwin"* ]]; then
   echo "create presto Base 64 encryption for generated key, cert, keystore, keystore password from mac workstation"
   PRESTO_KEYSTORE_PASS_B64=`echo -n "$KEYSTORE_PASSWORD" |base64`
   PRESTO_KEYSTORE_B64=`cat presto-keystore |base64`
   PRESTO_CERT_B64=`cat presto-cert.pem |base64`
   PRESTO_KEY_B64=`cat presto-key.pem |base64`
elif [[ "$OSTYPE" == "linux-gnu" ]] || [[ "$OSTYPE" == "linux-musl" ]]; then
   echo "create presto Base 64 encryption for generated key, cert, keystore, keystore password from linux workstation"
   PRESTO_KEYSTORE_PASS_B64=`echo -n "$KEYSTORE_PASSWORD" |base64 -w 0`
   PRESTO_KEYSTORE_B64=`cat presto-keystore |base64 -w 0`
   PRESTO_CERT_B64=`cat presto-cert.pem |base64 -w 0`
   PRESTO_KEY_B64=`cat presto-key.pem |base64 -w 0`
else
   echo "OSTYPE is not supported"
   exit
fi

#echo "Presto keystore password"
#echo $PRESTO_KEYSTORE_PASS_B64
#echo "####################################################"
#echo "presto keystore"
#echo $PRESTO_KEYSTORE_B64
#echo "####################################################"
#echo "presto cert"
#echo $PRESTO_CERT_B64
#echo "####################################################"
#echo "presto key"
#echo $PRESTO_KEY_B64
#echo "####################################################"

# feed the base64 outputs of key, cert, keystore, and keystore password into https-presto.yaml file

echo "feed the base64 outputs of key, cert, keystore, and keystore password into https-presto.yaml file"
cp https-presto-template.yaml https-presto.yaml


if [[ "$OSTYPE" == "darwin"* ]]; then
   sed -i .bak "s|KEYSTORE|${PRESTO_KEYSTORE_B64}|" https-presto.yaml
   sed -i .bak "s|KEYPASS|${PRESTO_KEYSTORE_PASS_B64}|" https-presto.yaml
   sed -i .bak "s|CERTPEM|${PRESTO_CERT_B64}|" https-presto.yaml
   sed -i .bak "s|KEYPEM|${PRESTO_KEY_B64}|" https-presto.yaml
elif [[ "$OSTYPE" == "linux-gnu" ]] || [[ "$OSTYPE" == "linux-musl" ]]; then
   sed -i "s|KEYSTORE|${PRESTO_KEYSTORE_B64}|" https-presto.yaml
   sed -i "s|KEYPASS|${PRESTO_KEYSTORE_PASS_B64}|" https-presto.yaml
   sed -i "s|CERTPEM|${PRESTO_CERT_B64}|" https-presto.yaml
   sed -i "s|KEYPEM|${PRESTO_KEY_B64}|" https-presto.yaml
else
   echo "OSTYPE is not supported"
   exit
fi

echo "https.yaml file is updated"
echo "kubectl apply -f https.yaml -n $NAMESPACE"
#kubectl apply -f https-presto.yaml -n $NAMESPACE
kubectl get secrets -n $NAMESPACE |grep presto
echo "install steps for presto SSL cert, pem, keystore on K8s cluster is completed"
