#!/bin/bash
source /dashbase/.bash_profile

export KUBE_HOME=~/.kube/
export KUBE_CONF=$KUBE_HOME/config

mkdir -p ~/.kube

if [[ ! -f "$KUBE_CONF" ]]; then
    cp $DASHBASE_HOME/config $KUBE_CONF
fi

# install aws cli
curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "/tmp/awscli-bundle.zip"
unzip /tmp/awscli-bundle.zip
/dashbase/awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws

ln -s /usr/local/lib/dashbase/.aws /root/.aws

/bin/bash
