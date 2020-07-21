#!/bin/bash

NODES=$(kubectl get nodes |sed -e 1d |awk '{print $1}' |tr '\n' ' ')
#echo $NODES

for ND in $NODES ; do
   #echo $ND
   CPU=$(kubectl describe node $ND |grep "cpu\:" |tail -1 |awk '{ print $2}' |sed -e 's/m//g')
   MEM=$(kubectl describe node $ND |grep "memory\:" |tail -1 |awk '{ print $2}' |sed -e 's/Ki//g')
   #echo $CPU
   #echo $((MEM / (1024*1024))) | sed 's/..$/.&/'
   sumcpu=$(($sumcpu + $CPU))
   summem=$(($summem + $MEM))

done

TMEMGI=$((summem / (1024*1024)))
echo "Total K8s cluster allowed CPU to use: ${sumcpu}m"
echo "Total K8s cluster allowed Memory to use: ${TMEMGI}Gi"