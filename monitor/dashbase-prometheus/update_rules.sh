#!/bin/bash

python3 -m venv venv
. venv/bin/activate
BASEDIR="$(cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd)"
KIND=$1
RULES=$(ls $BASEDIR/operator_resources/$KIND)
for filename in $RULES
do
   /bin/cat $BASEDIR/prometheus-operator/$KIND/$filename | yq --yaml-output  -w 1000 .spec > $BASEDIR/$KIND/$filename
done