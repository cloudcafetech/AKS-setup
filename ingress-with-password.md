## Setup ingress with password.

- Make sure you have following package installed.

```yum -y install httpd-tools```

- Create an auth file with username and password

```htpasswd -b -c auth promadmin Promadmin@12345```

- Create the secret for credentials

```kubectl create secret generic basic-auth --from-file=auth```

- Add following content in annotations of prometheus ingress

```
  annotations:
    kubernetes.io/ingress.class: "nginx"
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: basic-auth
    nginx.ingress.kubernetes.io/auth-realm: "Prometheus Authentication Required"
```
