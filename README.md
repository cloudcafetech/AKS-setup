## Azure Kubernetes Service (AKS)
Managed Kubernetes simplifies deployment, management and operations of Kubernetes, and allows developers to take advantage of Kubernetes without worrying about the underlying plumbing to get it up running and freeing up developer time to focus on the applications. Different Cloud Providers are offering this service – for example Google Kubernetes Engine (GKE), Amazon has Elastic Container Service for Kubernetes (EKS), Microsoft has Azure Kubernetes Service (AKS).
Here we are going to setup AKS.

<p align="center">
  <img src="https://github.com/cloudcafetech/AKS-setup/blob/master/aks-architecture.PNG">
</p>

### Setup Azure Kubernetes Service (AKS)
Azure Kubernetes Service management can be done from a development VM as well as using Azure Cloud Shell.  
In my setup, I’m using an CentOS VM and I’ve install Azure CLI locally. 

##### - Install Azure CLI

```
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc

sudo sh -c 'echo -e "[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'

sudo yum install azure-cli -y 
```
##### - Login to Azure using Azure CLI & set the Subscription

```
az login 
az account set --subscription "Free Trial"
az account show --output table
```
##### - First Create a resource group to manage the AKS cluster resources.

```
RG=pkar-aks-rg
az group create --name $RG --location northeurope
```

##### -  Create the Virtual Network (vnet) and the subnet 

```
az network vnet create --resource-group $RG --name pkar-aks-vnet --address-prefixes 10.20.0.0/16 --subnet-name pkar-aks-prod-subnet --subnet-prefix 10.20.1.0/24
az network vnet subnet create --resource-group $RG --vnet-name pkar-aks-vnet --address-prefixes 10.20.2.0/24 -n pkar-aks-test-subnet
az network vnet create --resource-group $RG --name pkar-mgm-vnet --address-prefixes 10.30.0.0/16 --subnet-name pkar-mgm-bastion-subnet --subnet-prefix 10.30.1.0/24
az network vnet create --resource-group $RG --name pkar-mgm-vnet --address-prefixes 10.30.0.0/16 --subnet-name pkar-mgm-appsgw-subnet --subnet-prefix 10.30.2.0/24
```

##### -  Create a service principal and assign permissions
AKS uses service principal to access other azure services like ACR & others. Default role is contributor so use “–skip-assignment”. Other available roles are as follow:

- Owner (pull, push, and assign roles to other users)
- Contributor (pull and push)
- Reader (pull only access)

The following example output shows the application ID and password for your service principal. These values are used in additional steps to assign a role to the service principal and then create the AKS cluster: Copy output of following command

```
CLUSTER=prod-aks-win
mkdir $CLUSTER
cd $CLUSTER
ssh-keygen -f ssh-key-$CLUSTER -N ''
SP_PASSWD=$(az ad sp create-for-rbac --name pkar-app-sp --skip-assignment --query password --output tsv)
echo "$SP_PASSWD" > pkar-app-sp-password
```

To assign the correct delegations in the remaining steps, use the az network vnet show and az network vnet subnet show commands to get the required resource IDs. These resource IDs are stored as variables and referenced in the remaining steps:

```
VNET_ID=$(az network vnet show --resource-group $RG --name pkar-aks-vnet --query id -o tsv)
APPS_ID=$(az ad sp list --display-name pkar-app-sp --query [].appId --output tsv)
PROD_SUBNET_ID=$(az network vnet subnet show --resource-group $RG --vnet-name pkar-aks-vnet --name pkar-aks-prod-subnet --query id -o tsv)
TEST_SUBNET_ID=$(az network vnet subnet show --resource-group $RG --vnet-name pkar-aks-vnet --name pkar-aks-test-subnet --query id -o tsv)
```

Now assign the service principal for your AKS cluster Contributor permissions on the virtual network using the az role assignment create command. Provide your own <appId> as shown in the output from the previous command to create the service principal:
  
```
az role assignment create --assignee $APPS_ID --scope $PROD_SUBNET_ID --role Contributor
az role assignment create --assignee $APPS_ID --scope $UAT_SUBNET_ID --role Contributor
az role assignment create --assignee $APPS_ID --scope $SIT_SUBNET_ID --role Contributor
az role assignment create --assignee $APPS_ID --scope $VNET_ID --role Contributor
```

##### -  Get the latest available Kubernetes version in your preferred region into a bash variable. 

```
WINPASS="Adminkar@2675"
WINUSER=adminprod
NODEVM=Standard_DS2_v2
K8SV=$(az aks get-versions -l eastus --query 'orchestrators[-1].orchestratorVersion' -o tsv)
```

##### -  Create an AKS PROD cluster in the PROD Subnet

```
az aks create \
    --resource-group $RG \
    --name $CLUSTER \
    --node-count 1 \
    --network-plugin azure \
    --service-cidr 10.0.0.0/16 \
    --dns-service-ip 10.0.0.10 \
    --docker-bridge-address 172.17.0.1/16 \
    --vnet-subnet-id $PROD_SUBNET_ID \
    --ssh-key-value "ssh-key-$CLUSTER.pub" \
    --windows-admin-password $WINPASS \
    --windows-admin-username $WINUSER \
    --vm-set-type VirtualMachineScaleSets \
    --network-plugin azure \
    --node-osdisk-size 80 \
    --node-vm-size $NODEVM \
    --nodepool-name coreaksp \
    --kubernetes-version $K8SV \
    --service-principal $APPS_ID \
    --tags 'env=prod' 'app=Aks Windows' \
    --client-secret "$SP_PASSWD"
```

##### -  Add another nodepoll for infra in AKS PROD cluster.

```
az aks nodepool add \
    --resource-group $RG \
    --cluster-name $CLUSTER \
    --os-type Windows \
    --name wiaksp \
    --node-vm-size $NODEVM \
    --node-count 1 \
    --enable-node-public-ip \    
    --kubernetes-version $K8SV
```

##### -  Install kubectl 

```sudo az aks install-cli```

##### -  Connect to AKS Cluster (Get Credencials & setup environment)

``` 
az aks get-credentials --resource-group $RG --name $CLUSTER
export KUBECONFIG=/root/.kube/config
kubectl config get-clusters
kubectl config current-context
kubectl get nodes
```

##### -  Install windows exporter

Download and run following script

```
wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/winexporter-setup.sh; chmod +x winexporter-setup.sh
./winexporter-setup.sh
```

##### -  Install monitoring

Download and run following script

```
wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/monitoring-setup.sh; chmod +x monitoring-setup.sh
./monitoring-setup.sh
```

##### -  Install Sample Application

Download and run following yaml

```
wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/hotel-app-win-aks.yaml
wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/sampleapp.yaml
kubectl create -f hotel-app-win-aks.yaml -f sampleapp.yaml
```

### Some usefull command for AKS

##### - To Start/Stop AKS Cluster

```
wget https://raw.githubusercontent.com/cloudcafetech/AKS-setup/master/aks-start-stop.sh; chmod +x aks-start-stop.sh
./aks-start-stop.sh { start | stop }
```
##### -  Create NSG rule (allow access) to login AKS nodes
AKS node pool subnets are protected with NSGs (Network Security Groups) by default. To get access to the virtual machine, enabled access in the NSG.

```
SOURCE_IP=<SOURCE-PUBLIC-OR-PRIVATE-IP>
CLUSTER_RG=$(az aks show -g $RG -n $CLUSTER --query nodeResourceGroup -o tsv)
NSG_NAME=$(az network nsg list -g $CLUSTER_RG --query [].name -o tsv)
az network nsg rule create --name tempSSHAccess --resource-group $CLUSTER_RG --nsg-name $NSG_NAME --priority 100 --source-address-prefixes $SOURCE_IP --destination-port-range 22 --protocol Tcp --description "Temporary ssh access to Windows nodes"	
```

##### -  Remove temporary access (NSG rules) to the Windows VM (node)

```az network nsg rule delete --resource-group $CLUSTER_RG --nsg-name $NSG_NAME --name tempSSHAccess```

##### - Scale node pool

```az aks nodepool scale --resource-group $RG --cluster-name $CLUSTER --name <NODEPOOL-NAME> --node-count 1 --no-wait```

##### -  POD to POD communication accross ALL nodes
As we are building cluster in custom VNET, need to update routing table otherwise pod will communicates with other Pods on same node not other node. Basically When using pre-existing VNET and subnet (not dedicated to AKS) the routing table with UDRs for the AKS nodes is not attached to the subnet the nodes are deployed to by default, which means that the pods have no way to reach each other across nodes.

```
PROD_SUBNET_ID=$(az network vnet subnet show --resource-group pkar-aks-rg --vnet-name pkar-aks-vnet --name pkar-aks-prod-subnet --query id -o tsv)
AKS_MC_RG=$(az group list --query "[?starts_with(name, 'MC_${AKS_RG}')].name | [0]" --output tsv)
rt=$(az network route-table list -g $AKS_MC_RG -o json | jq -r '.[].id')
az network vnet subnet update -g pkar-aks-rg --route-table $rt --ids $PROD_SUBNET_ID
```
##### Ref: https://github.com/Azure/aks-engine/blob/master/docs/tutorials/custom-vnet.md

##### -  Setup Bastion VM in Managment VNET

```
az vm create \
    --resource-group pkar-aks-rg \
    --name pkar-mgm-bastion-vm \
    --vnet-name pkar-mgm-vnet \
    --subnet pkar-mgm-bastion-subnet \
    --image OpenLogic:CentOS:7.5:latest \
    --size Standard_DS1_v2 \
    --admin-username azureuser 
    --ssh-key-value ~/.ssh/id_rsa.pub
    
openssl rsa -in ~/.ssh/id_rsa -outform pem > id_rsa.pem

yum install epel-release putty curl git zip wget httpd-tools jq -y
puttygen id_rsa.pem -o azure.ppk -O private    
```

##### -  Install Helm, run the following commands:

```
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
```

##### -  To create a ServiceAccount and associate it with the predefined cluster-admin role, use a ClusterRoleBinding, as below:

```
kubectl create serviceaccount -n kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
```

##### -  Initialize Helm as shown below:

```helm init --service-account tiller```

##### -  Peering AKS VNET & Managment VNET

```  
az network vnet peering create -g pkar-aks-rg -n mgm-vnet-to-aks-vnet --vnet-name pkar-mgm-vnet --remote-vnet pkar-aks-vnet --allow-vnet-access
```

### Setup Azure Container Registry (ACR)
Azure Container Registry (ACR) is a managed Docker registry service based on the open-source Docker Registry.  It is a secure private registry managed by Azure, and also a managed service so Azure handles the security, backend infrastructure and storage so the developers can focus on their applications. ACR allows you to store images for all types of container deployments. Below step-by-step process of ACR creation and integration with Azure Kubernetes Service (AKS) using Azure Service Principal.

##### - Login to Azure using Azure CLI & set the Subscription

```
az login -u <username> -p <password>
az account set --subscription "Microsoft Azure XXXX"
az account show -o table
az account show
```

##### -  Create Azure Container Registry (ACR)
ACR name should be unique

``` 
az acr create --name pkaraksacr --resource-group pkar-aks-rg --sku standard --location eastus
az acr list -o table
```

##### - Login to ACR 
Before login please verify if docker is installed.

```
az acr login -n pkaraksacr
az acr list -o table
```

##### - Push docker image to ACR 
Before login please verify if docker is installed. First download image from docker, tag the image then push to ACR.

```
docker pull prasenforu/employee
docker tag prasenforu/employee:latest pkaraksacr.azurecr.io/prod/employee:latest
docker push pkaraksacr.azurecr.io/prod/employee:latest
az acr repository list -n pkaraksacr -o table
```

##### - Use ACR with AKS

- Get the id of the service principal configured for AKS

```
CLIENT_ID=$(az aks show --resource-group pkar-aks-rg --name pkar-aks-cluster --query "servicePrincipalProfile.clientId" --output tsv)
APPS_ID=$(az ad sp list --display-name pkar-app-sp --query [].appId --output tsv)
```

- Get the resource ID of ACR

```ACR_ID=$(az acr show --name pkaraksacr --resource-group pkar-aks-rg --query "id" --output tsv)```

- Assign reader role to ACR Resource  

``` az role assignment create --assignee $CLIENT_ID --role Reader --scope $ACR_ID```

##### - ACR commands

```
az acr list --resource-group pkar-aks-rg --query [].loginServer -o table
az acr repository list -n pkaraksacr -o table
az acr repository show-tags --name pkaraksacr --repository prod/employee -o table
```

### Azure Application Gwateway
Azure Application Gateway is an advance type of load-balancer. Where an Azure Load-balancer routes traffic on the transport layer (OSI Layer 4 | TCP + UDP) the Application Gateway is a way more advanced load-balancer. It can route based on URL as well on path’s. On top of that it can do much more, like SSL offloading, autoscaling, redirection, multiple site hosting and the most import of all, it can include a web application firewall (WAF).

<p align="center">
  <img src="https://github.com/cloudcafetech/AKS-setup/blob/master/ingress-agw1.PNG">
</p>

##### - Create the application gateway

```
az network application-gateway create \
  --name aks-prod-agw \
  --location eastus \
  --resource-group pkar-aks-rg \
  --vnet-name pkar-mgm-vnet \
  --subnet pkar-mgm-appsgw-subnet \
  --capacity 1 \
  --sku WAF_Medium \
  --http-settings-cookie-based-affinity Disabled \
  --frontend-port 80 \
  --http-settings-port 80 \
  --http-settings-protocol Http \
  --public-ip-address pkar-aks-appgw-pip
```

##### - Add the backend pools
Backend pools named aks-prod-ingress that are pointed to ingress controller internal service IP as a backend servers.
Here we are using In-cluster ingress controllers and traffic should flow from application gateway to ingress controller then respective service.

```
az network application-gateway address-pool create \
  --gateway-name aks-prod-agw \
  --resource-group pkar-aks-rg \
  --name aks-prod-ingress \
  --servers <Ingress-Controller-SVC-Private-IP>
```

##### - Add listeners
A listener is required to enable the application gateway to route traffic appropriately to the backend pool. 
In this listeners are created for the domains of asd.apps.cloud-cafe.cf

```
az network application-gateway http-listener create \
  --name asd-apps-cloud-cafe-cf-lis \
  --frontend-ip appGatewayFrontendIP \
  --frontend-port appGatewayFrontendPort \
  --resource-group pkar-aks-rg \
  --gateway-name aks-prod-agw \
  --host-name asd.apps.cloud-cafe.cf
```

##### - Create & add custom Health Probe

```
az network application-gateway probe create \
  --gateway-name aks-prod-agw \
  --resource-group pkar-aks-rg \
  --name asd.apps.cloud-cafe.cf-probe \
  --protocol http \
  --host asd.apps.cloud-cafe.cf \
  --match-status-codes 200-401 \  
  --path /
```

##### - Add Http settings

```
az network application-gateway http-settings create \
  --resource-group pkar-aks-rg \
  --gateway-name aks-prod-agw \
  --name asd.apps.cloud-cafe.cf-http \
  --port 80 \
  --protocol Http \
  --cookie-based-affinity Disabled \
  --enable-probe true \
  --probe asd.apps.cloud-cafe.cf-probe \
  --timeout 30
```

##### - Add routing rules
Rules are processed in the order in which they are created, and traffic is directed using the first rule that matches the URL sent to the application gateway. Create new rules.

```
az network application-gateway rule create \
  --gateway-name aks-prod-agw \
  --name asd.apps.cloud-cafe.cf-rule \
  --resource-group pkar-aks-rg \
  --http-listener asd-apps-cloud-cafe-cf-lis \
  --rule-type Basic \
  --address-pool aks-prod-ingress \
  --http-settings asd.apps.cloud-cafe.cf-http
```

And delete the default rule that was created when you created the application gateway. 
```
az network application-gateway rule delete \
  --gateway-name aks-prod-agw \
  --resource-group pkar-aks-rg \
  --name rule1
az network application-gateway http-settings delete \
  --gateway-name aks-prod-agw \
  --resource-group pkar-aks-rg \
  --name appGatewayBackendHttpSettings
az network application-gateway address-pool delete \
  --gateway-name aks-prod-agw \
  --resource-group pkar-aks-rg \
  --name appGatewayBackendPool
az network application-gateway http-listener delete \
  --gateway-name aks-prod-agw \
  --resource-group pkar-aks-rg \
  --name appGatewayHttpListener
```

##### - Add routing table
Add aks (aks-agentpool-76756387-routing table) routing table in pkar-mgm-appsgw-subnet.

##### - Add multiple hosts

1. Health Probe
2. HTTP settings
3. AGW Listeners
4. Rule creation

##### Ref : 
https://www.domstamand.com/end-to-end-ssl-solution-using-web-apps-and-azure-application-gateway-multisite-hosting/

https://medium.com/@shawnlu_86806/application-gateway-work-with-aks-via-ssl-9894e7f4a587
