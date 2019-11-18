#!/bin/bash

# make sure dashbase home directory exists
mkdir -p ~/.dashbase/collector
export DASHBASE_HOME=~/.dashbase
curl https://raw.githubusercontent.com/dashbase/dashbase-installation/d5f450c12eb837538780142765a85848ce27635d/configs/dashcomm/values.yml > $DASHBASE_HOME/values.yml
docker run -it -v "$DASHBASE_HOME":"/usr/local/lib/dashbase/" dashbase/dashbase-admin
