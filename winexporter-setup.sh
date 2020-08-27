#!/bin/bash
# Windows Nodes Exporter setup script on AKS Windows Host

CLUSTER=prod-aks-win
WINUSER=adminprod

echo "Deploying AKS SSH POD on Cluster"
kubectl create -f https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/aks-ssh.yaml

echo "Waiting for SSH POD ready .."
while [[ $(kubectl get pods aks-ssh -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do printf '.'; sleep 2; done

echo "Copy ssh key to SSH POD"
kubectl cp ssh-key-$CLUSTER $(kubectl get pod aks-ssh | awk '{print $1}' | grep -v NAME):/ssh-key-$CLUSTER

for winhost in $(kubectl get nodes -o wide | grep Windows | awk '{print $6}'); do
  echo "Deploying Host Exporter on Windows Nodes"
  kubectl exec -it aks-ssh -- ssh -o 'StrictHostKeyChecking no' -i ssh-key-$CLUSTER $WINUSER@$winhost "curl -LO https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/windows-exporter-setup.bat && windows-exporter-setup.bat"
done

echo "Deleting SSH POD"
kubectl delete pod aks-ssh

# Cluster linux host login
#kubectl exec -it aks-ssh -- ssh -o 'StrictHostKeyChecking no' -i ssh-key-$CLUSTER azureuser@<LINUX HOST IP>

# Cluster Windows host login
#kubectl exec -it aks-ssh -- ssh -o 'StrictHostKeyChecking no' -i ssh-key-$CLUSTER $WINUSER@<Windows HOST IP>

# Exit container cleanup command
#docker rm `docker ps -a | grep -v CONTAINER | grep Exited | awk '{print $1}'`
