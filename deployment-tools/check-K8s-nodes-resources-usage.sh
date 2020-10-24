#!/bin/bash

NODES=$(kubectl get nodes |sed -e 1d |awk '{print $1}' |tr '\n' ' ')

for ND in $NODES ; do
   echo -e "$ND\t \
type $(kubectl describe node $ND |grep instance-type |cut -d"=" -f2)\t \
cpu $(kubectl describe node $ND |grep cpu |tail -1 |tail -1 |awk '{print $3,$5}')\t \
memory $(kubectl describe node $ND |grep memory |tail -1 |tail -1 |awk '{print $3,$5}')\t \
instance-id $(kubectl describe node $ND |grep "ProviderID:" |awk '{ print $2}' |cut -d'/' -f5)"

done