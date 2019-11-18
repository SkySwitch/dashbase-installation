#!/bin/bash

# make sure dashbase home directory exists
mkdir -p ~/.dashbase/collector
export DASHBASE_HOME=~/.dashbase

if [[ ! -f "$DASHBASE_HOME/values.yml" ]]; then
    curl https://raw.githubusercontent.com/dashbase/dashbase-installation/d5f450c12eb837538780142765a85848ce27635d/configs/dashcomm/values.yml > $DASHBASE_HOME/values.yml
fi

docker run -it -v "$DASHBASE_HOME":"/usr/local/lib/dashbase/" dashbase/dashbase-admin
