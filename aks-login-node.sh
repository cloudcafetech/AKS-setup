#!/bin/bash
# Kubernetes Nodes login script

CLUSTER=prod-aks-win
WINUSER=adminprod
LINUSER=azureuser
SSHKEY=ssh-key-$CLUSTER
HOSTIP=$2

echo "Deploying AKS SSH POD on Cluster"
kubectl create -f https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/aks-ssh.yaml

echo "Waiting for SSH POD ready .."
while [[ $(kubectl get pods aks-ssh -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do printf '.'; sleep 2; done

echo "Copy ssh key to SSH POD"
kubectl cp $SSHKEY $(kubectl get pod aks-ssh | awk '{print $1}' | grep -v NAME):/$SSHKEY

echo ""
echo "List of Nodes in AKS Cluster"
echo ""
kubectl get nodes -o wide | awk '{print $1 " - " $6 " - " $8}' | grep -v NAME

# To login linux node
linux()
 {
 kubectl exec -it aks-ssh -- ssh -o 'StrictHostKeyChecking no' -i $SSHKEY $LINUSER@$HOSTIP
 }

# To login windows node
windows()
 {
 kubectl exec -it aks-ssh -- ssh -o 'StrictHostKeyChecking no' -i $SSHKEY $WINUSER@$HOSTIP
 }

case "$1" in
    'linux')
            linux
            ;;
    'windows')
            windows
            ;;
    *)
            echo
            echo "Usage: $0 { linux | windows } <Node IP>"
            echo
            exit 1
            ;;
esac

exit 0

# Exit container cleanup command
#docker rm `docker ps -a | grep -v CONTAINER | grep Exited | awk '{print $1}'`
