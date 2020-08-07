#!/usr/bin/env bash
bin=`dirname "$0"`
bin=`cd "$bin"; pwd`
basedir=${bin}/..
appdir=${basedir}/examples/$1

echo ${appdir}

filebeat -c ${appdir}/filebeat.yml --path.config ${appdir} --path.data ${appdir} -e


