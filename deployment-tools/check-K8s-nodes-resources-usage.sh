#!/bin/bash

NODES=$(kubectl get nodes |sed -e 1d |awk '{print $1}' |tr '\n' ' ')

for ND in $NODES ; do
   echo $ND
   kubectl describe node $ND  |grep -E "cpu|memory" |grep -ivE "cpu\:|memory\:" |grep -iv MemoryPressure
done