#!/usr/bin/env bash
bin=`dirname "$0"`
bin=`cd "$bin"; pwd`
basedir=${bin}/..
apptype=$1
appdir=${basedir}/examples/${apptype}
echo ${appdir}

curl -H -XGET 'http://localhost:7888/_ingest/pipeline/$apptype'
