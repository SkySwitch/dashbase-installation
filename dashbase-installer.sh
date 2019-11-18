#!/bin/bash

# make sure dashbase home directory exists
mkdir -p ~/.dashbase/collector
export DASHBASE_HOME=~/.dashbase

# download a new default values.yml if none exists
if [[ ! -f "$DASHBASE_HOME/values.yml" ]]; then
    echo "Downloading a default deployment template"
    curl https://raw.githubusercontent.com/dashbase/dashbase-installation/d5f450c12eb837538780142765a85848ce27635d/configs/dashcomm/values.yml > $DASHBASE_HOME/values.yml
else
    echo "Deployment template exists"
fi

# the kubernetes config in the default location exists
# copy to DASHBASE_HOME if none exists
if [[ ! -f "$DASHBASE_HOME/config" ]]; then
    if [[ ! -f "~/.kube/config" ]]; then
        echo "Copying existing Kubernetes config"
        cp ~/.kube/config $DASHBASE_HOME/config
    else
        echo "No existing Kubernetes config (~/.kube/config)! Please setup a Kubernetes cluster, and place the config file under ~/.kube"
    fi
else
    echo "Kubernetes config exists"    
fi

# run the dashbase admin docker image
docker run -it -v "$DASHBASE_HOME":"/usr/local/lib/dashbase/" dashbase/dashbase-admin
