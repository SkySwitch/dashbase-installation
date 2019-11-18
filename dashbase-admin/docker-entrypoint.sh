#!/bin/bash
source /dashbase/.bash_profile

export KUBE_HOME=~/.kube/
export KUBE_CONF=$KUBE_HOME/config

mkdir -p ~/.kube

if [[ ! -f "$KUBE_CONF" ]]; then
    cp $DASHBASE_HOME/config $KUBE_CONF
fi

/bin/bash