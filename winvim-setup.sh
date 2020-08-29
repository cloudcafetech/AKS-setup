#!/bin/bash
# Windows vi setup script on AKS Windows Host

CLUSTER=prod-aks-win
WINUSER=adminprod
SSHKEY=ssh-key-$CLUSTER

echo "Deploying AKS SSH POD on Cluster"
kubectl create -f https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/aks-ssh.yaml

echo "Waiting for SSH POD ready .."
while [[ $(kubectl get pods aks-ssh -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do printf '.'; sleep 2; done

echo "Copy ssh key to SSH POD"
kubectl cp $SSHKEY $(kubectl get pod aks-ssh | awk '{print $1}' | grep -v NAME):/$SSHKEY

for winhost in $(kubectl get nodes -o wide | grep Windows | awk '{print $6}'); do
  echo "Deploying Host Exporter on Windows Nodes"
  kubectl exec -it aks-ssh -- ssh -o 'StrictHostKeyChecking no' -i $SSHKEY $WINUSER@$winhost "curl -LO https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/windows-vim-setup.bat && windows-vim-setup.bat"
done

echo "Deleting SSH POD"
kubectl delete pod aks-ssh
