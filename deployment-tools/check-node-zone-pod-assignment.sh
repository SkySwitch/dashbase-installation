#!/bin/bash

NODES=$(kubectl get nodes |sed -e 1d |awk '{print $1}' |tr '\n' ' ')

for ND in $NODES ; do
	echo -e "$ND\t \
$(kubectl describe node $ND  |grep "ProviderID:" |awk '{ print $2}' |sed 's|aws:///||') \
$(kubectl describe node $ND  |grep nodegroup-name |grep -iv "nodegroup-type" |cut -d"/" -f2 |cut -d"=" -f2)\t\
$(kubectl describe node $ND  |grep indexer |awk '{print $2}'|tr '\n' ' ') \
$(kubectl describe node $ND  |grep coredns |awk '{print $2}'|cut -d"-" -f1|tr '\n' ' ') \
$(kubectl describe node $ND  |grep web |awk '{print $2}'|tr '\n' ' ') \
$(kubectl describe node $ND  |grep auth |awk '{print $2}'|tr '\n' ' ') \
$(kubectl describe node $ND  |grep prometheus-0 |grep -iv eght|awk '{print $2}' |tr '\n' ' ') \
$(kubectl describe node $ND  |grep grafana-0 |awk '{print $2}'|tr '\n' ' ') \
$(kubectl describe node $ND  |grep table-manager |awk '{print $2}' |cut -d"-" -f1,2,3|tr '\n' ' ') \
$(kubectl describe node $ND  |grep searcher |awk '{print $2}'|cut -d"-" -f1|tr '\n' ' ') \
$(kubectl describe node $ND  |grep admindash |awk '{print $2}'|tr '\n' ' ') \
$(kubectl describe node $ND  |grep "api-" |awk '{print $2}' |tr '\n' ' ') \
$(kubectl describe node $ND  |grep "etcd-operator" |awk '{print $2}'|sed -e 's/dashbase\-etcd\-etcd\-operator\-//' |cut -d"-" -f1,2,3 |tr '\n' ' ') \
$(kubectl describe node $ND  |grep "etcd-cluster" |awk '{print $2}'|cut -d"-" -f1,2 |tr '\n' ' ')"
done

