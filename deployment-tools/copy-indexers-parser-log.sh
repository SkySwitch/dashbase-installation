#!/bin/bash

mkdir -p paser-logs-$(date +"%Y-%m-%d-%H-%M-%S")
LOGDIR=$(ls -ltd paser-logs* |tail -1 | awk '{print $NF}')
LOGFILE="filebeat-parser.log"
echo "created paser log folder $LOGDIR"
INXER=$(kubectl get po -n dashbase |grep indexer |awk '{print $1}' |tr '\n' ' ')

for NDX in $INXER ; do
	echo -e "$NDX"
	kubectl cp dashbase/"$NDX":/app/logs/"$LOGFILE" ./"$LOGDIR"/"$NDX"-"$LOGFILE"
done

echo "please  check the parser logs from  this folder $LOGDIR"