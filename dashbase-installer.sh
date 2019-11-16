#!/bin/bash

# make sure dashbase home directory exists
mkdir -p ~/.dashbase/collector
export DASHBASE_HOME=~/.dashbase
docker run -it -v "$DASHBASE_HOME":"/usr/local/lib/dashbase/" dashbase/dashbase-admin


