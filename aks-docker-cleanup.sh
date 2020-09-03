#!/bin/bash
# Windows Nodes Exporter setup script on AKS Windows Host

CLUSTER=prod-aks-win
WINUSER=adminprod
LINUSER=azureuser
SSHKEY=ssh-key-$CLUSTER

echo "Deploying AKS SSH POD on Cluster"
kubectl create -f https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/aks-ssh.yaml

echo "Waiting for SSH POD ready .."
while [[ $(kubectl get pods aks-ssh -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do printf '.'; sleep 2; done

echo "Copy ssh key to SSH POD"
kubectl cp $SSHKEY $(kubectl get pod aks-ssh | awk '{print $1}' | grep -v NAME):/$SSHKEY

for winhost in $(kubectl get nodes -o wide | grep Windows | awk '{print $6}'); do
  echo "Deleting Exited and Created container on Windows Nodes"
  kubectl exec -it aks-ssh -- ssh -o 'StrictHostKeyChecking no' -i $SSHKEY $WINUSER@$winhost 'powershell -Command "$list = docker ps -a -q -f status=exited;docker rm -v $list"'
done

for linhost in $(kubectl get nodes -o wide | grep -v Windows | grep -v INTERNAL-IP | awk '{print $6}'); do
  echo "Deleting Exited and Created container on Linux Nodes"
  kubectl exec -it aks-ssh -- ssh -o 'StrictHostKeyChecking no' -i $SSHKEY $LINUSER@$linhost 'list=`docker ps -a -q -f status=exited`; docker rm -v $list'
done

echo "Deleting SSH POD"
kubectl delete pod aks-ssh
