
## Azure Application Gateway

Azure Application Gateway is an advance type of load-balancer. Where an Azure Load-balancer routes traffic on the transport layer (OSI Layer 4 | TCP + UDP) the Application Gateway is a way more advanced load-balancer. It can route based on URL as well on path’s. On top of that it can do much more, like SSL offloading, autoscaling, redirection, multiple site hosting and the most import of all, it can include a web application firewall (WAF). 

Some of Application Gateway features ..

- URL-based routing: make routing decisions based on additional attributes of an HTTP request, such as URI path or host headers. For example, you can route traffic based on the incoming URL. So if /images is in the incoming URL, you can route traffic to a specific set of servers (known as a pool) configured for images. If /video is in the URL, that traffic is routed to another pool that’s optimized for videos
- Multiple-site hosting: enables you to configure more than one web site on the same application gateway instance
- Redirection: redirect traffic received at one listener to another listener or to an external site
- Session affinity (sticky sessions): keep a user session on the same server
- Websocket and HTTP/2 traffic: provides native support for the WebSocket and HTTP/2 protocols
- Azure Kubernetes Service (AKS) Ingress controller: Application Gateway Ingress controller runs as a pod within the AKS cluster and allows Application Gateway to act as ingress for an AKS cluster (*v2 only and currently in preview as the time of writing)
- HTTP headers rewrite: supports the capability to add, remove, or update HTTP request and response headers, while the request and response packets move between the client and back-end pools. It also provides you with the capability to add conditions to ensure the specified headers are rewritten only when certain conditions are met
- Custom error pages: create custom error pages instead of displaying default error pages
- SSL/TLS termination: allow unencrypted traffic between the application gateway and the backend servers saving some of the processing load needed to encrypt and decrypt said traffic

One key feature of the Application Gateway service is its support for Secure Sockets Layer (SSL) termination. This feature means that the overhead of encrypting and decrypting traffic can be offloaded to the gateway, rather than have this impact performance on the backend web server.

This does however mean that communication between the application gateway and the backend web server is unencrypted which in some cases, perhaps due to security or compliance requirements, may not be acceptable. For those situations, the application gateway also fully supports end to end SSL encryption.

For the purpose of this setup, the assumption has been made that SSL termination is enabled on the gateway. Standard web traffic should now be redirected to the HTTPS listener so that web requests don’t just fail when they are unable to traverse the application gateway over HTTP.
This setup an application gateway with multiple site hostname match and http to https redirect. When an application gateway is configured with SSL termination, a routing rule(2) is used to redirect HTTP traffic to the HTTPS listener. 


<p align="center">
  <img src="https://github.com/prasenforu/Kube-platform/blob/master/AKS/ingress-agw1.PNG">
</p>

### Setup Application Gateway

- SSL (self sign) wild card certifcate generate

```
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
 -out aks-ingress-tls.crt \
 -keyout aks-ingress-tls.key \
 -subj "/CN=*.apps.cloud-cafe.cf/O=aks-ingress-tls"

openssl pkcs12 -export -out aks-ingress-tls.pfx -inkey aks-ingress-tls.key -in aks-ingress-tls.crt -password pass:Azure@12345
```

- Create the application gateway

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
  --frontend-port 443 \
  --http-settings-port 80 \
  --http-settings-protocol Http \
  --public-ip-address pkar-aks-appgw-pip \
  --cert-file aks-ingress-tls.pfx \
  --cert-password "Azure@12345" 
```

- Add the backend pools

```
az network application-gateway address-pool create \
  --gateway-name aks-prod-agw \
  --resource-group pkar-aks-rg \
  --name aks-prod-ingress \
  --servers <Ingress-Controller-SVC-Private-IP>
```

- Add new frontend port

```
az network application-gateway frontend-port create \
  --port 80 \
  --resource-group pkar-aks-rg \
  --gateway-name aks-prod-agw \
  --name httpPort
```

- Add HTTP listener

```
az network application-gateway http-listener create \
  --name asd.apps.cloud-cafe.cf-http \
  --frontend-ip appGatewayFrontendIP \
  --frontend-port httpPort \
  --resource-group pkar-aks-rg \
  --gateway-name aks-prod-agw \
  --host-name asd.apps.cloud-cafe.cf
```

- Add HTTPS listener

```
az network application-gateway http-listener create \
  --name asd.apps.cloud-cafe.cf-https \
  --frontend-ip appGatewayFrontendIP \
  --frontend-port appGatewayFrontendPort \
  --resource-group pkar-aks-rg \
  --gateway-name aks-prod-agw \
  --ssl-cert aks-prod-agwSslCert \
  --host-name asd.apps.cloud-cafe.cf
```

- Create & add custom Health Probe

```
az network application-gateway probe create \
  --gateway-name aks-prod-agw \
  --resource-group pkar-aks-rg \
  --name asd.apps.cloud-cafe.cf \
  --protocol http \
  --host asd.apps.cloud-cafe.cf \
  --match-status-codes 200-401 \  
  --path /
```

- Add Http settings

```
az network application-gateway http-settings create \
  --resource-group pkar-aks-rg \
  --gateway-name aks-prod-agw \
  --name asd.apps.cloud-cafe.cf \
  --port 80 \
  --protocol Http \
  --cookie-based-affinity Disabled \
  --enable-probe true \
  --probe asd.apps.cloud-cafe.cf \
  --timeout 30
```

- Create redirect config

```
az network application-gateway redirect-config create \
  --name asd.apps.cloud-cafe.cf-http-redirect \
  --gateway-name aks-prod-agw \
  --resource-group pkar-aks-rg \
  --type Permanent \
  --target-listener asd.apps.cloud-cafe.cf-https \
  --include-path true \
  --include-query-string true
```

- Create redirect rule to http listener

```
az network application-gateway rule create \
  --resource-group pkar-aks-rg \
  --gateway-name aks-prod-agw \
  --name asd.apps.cloud-cafe.cf-http-redirect \
  --http-listener asd.apps.cloud-cafe.cf-http \
  --rule-type Basic \
  --redirect-config asd.apps.cloud-cafe.cf-http-redirect
```

- Create rule to https listener

```
az network application-gateway rule create \
  --resource-group pkar-aks-rg \
  --gateway-name aks-prod-agw \
  --name asd.apps.cloud-cafe.cf \
  --http-listener asd.apps.cloud-cafe.cf-https \
  --http-settings asd.apps.cloud-cafe.cf \
  --rule-type Basic \
  --address-pool aks-prod-ingress
```

- Delete the default , backendpool, rule, listener & http-settings that was created when you created the application gateway.

```
az network application-gateway rule delete \
  --gateway-name aks-prod-agw \
  --resource-group pkar-aks-rg \
  --name rule1

az network application-gateway http-settings delete \
  --gateway-name aks-prod-agw \
  --resource-group pkar-aks-rg \
  --name appGatewayBackendHttpSettings

az network application-gateway http-listener delete \
  --gateway-name aks-prod-agw \
  --resource-group pkar-aks-rg \
  --name appGatewayHttpListener

az network application-gateway address-pool delete \
  --gateway-name aks-prod-agw \
  --resource-group pkar-aks-rg \
  --name appGatewayBackendPool
```

### Adding more urls (below sequence)

1. Health Probe
2. HTTP settings
3. AGW Listeners (HTTP & HTTPS)
4. Redirect-config
5. Rule creation

- Create Health Probe

```
az network application-gateway probe create \
  --gateway-name aks-prod-agw \
  --resource-group pkar-aks-rg \
  --name prom.apps.cloud-cafe.cf \
  --protocol http \
  --host prom.apps.cloud-cafe.cf \
  --match-status-codes 200-401 \  
  --path /
```

- Create HTTP settings

```
az network application-gateway http-settings create \
  --resource-group pkar-aks-rg \
  --gateway-name aks-prod-agw \
  --name prom.apps.cloud-cafe.cf \
  --port 80 \
  --protocol Http \
  --cookie-based-affinity Disabled \
  --enable-probe true \
  --probe prom.apps.cloud-cafe.cf \
  --timeout 30
```

- Create HTTP listener

```
az network application-gateway http-listener create \
  --name prom.apps.cloud-cafe.cf-http \
  --frontend-ip appGatewayFrontendIP \
  --frontend-port httpPort \
  --resource-group pkar-aks-rg \
  --gateway-name aks-prod-agw \
  --host-name prom.apps.cloud-cafe.cf
```

- Create HTTPS listener

```
az network application-gateway http-listener create \
  --name prom.apps.cloud-cafe.cf-https \
  --frontend-ip appGatewayFrontendIP \
  --frontend-port appGatewayFrontendPort \
  --resource-group pkar-aks-rg \
  --gateway-name aks-prod-agw \
  --ssl-cert aks-prod-agwSslCert \
  --host-name prom.apps.cloud-cafe.cf
```

- Create redirect config

```
az network application-gateway redirect-config create \
  --name prom.apps.cloud-cafe.cf-http-redirect \
  --gateway-name aks-prod-agw \
  --resource-group pkar-aks-rg \
  --type Permanent \
  --target-listener prom.apps.cloud-cafe.cf-https \
  --include-path true \
  --include-query-string true
```

- Create redirect rule to http listener

```
az network application-gateway rule create \
  --resource-group pkar-aks-rg \
  --gateway-name aks-prod-agw \
  --name prom.apps.cloud-cafe.cf-http-redirect \
  --http-listener prom.apps.cloud-cafe.cf-http \
  --rule-type Basic \
  --redirect-config prom.apps.cloud-cafe.cf-http-redirect
```

- Create rule to https listener

```
az network application-gateway rule create \
  --resource-group pkar-aks-rg \
  --gateway-name aks-prod-agw \
  --name prom.apps.cloud-cafe.cf \
  --http-listener prom.apps.cloud-cafe.cf-https \
  --http-settings prom.apps.cloud-cafe.cf \
  --rule-type Basic \
  --address-pool aks-prod-ingress
```
