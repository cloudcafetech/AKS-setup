#!/bin/bash
# AKS Cluster Start/Stop script

RG=pkar-aks-rg
CLUSTER=prod-aks-win
CLUSTER_RG=$(az aks show -g $RG -n $CLUSTER --query nodeResourceGroup -o tsv)

# To Stop AKS Cluster
stop()
 {
 for i in $(az vmss list --resource-group $CLUSTER_RG -o table | awk '{print $1}' | grep aks); do
  echo "Stoping & deallocating AKS Cluster .."
  az vmss deallocate --resource-group $CLUSTER_RG --name $i --instance-ids 0
 done
 }

# To Start AKS Cluster
start()
 {
 for i in $(az vmss list --resource-group $CLUSTER_RG -o table | awk '{print $1}' | grep aks); do
  echo "Starting AKS Cluster .."
  az vmss start --resource-group $CLUSTER_RG --name $i --instance-ids 0
 done
 }

case "$1" in
    'start')
            start
            ;;
    'stop')
            stop
            ;;
    *)
            echo
            echo "Usage: $0 { start | stop }"
            echo
            exit 1
            ;;
esac

exit 0
