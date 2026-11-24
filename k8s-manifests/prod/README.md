```shell
##################
# Cluster setup. #
##################

# Cluster should have Gateway API resources.
# This instruction assumes that a cluster will have traefik gateway api implementation.

kubectl config use-context <the context of a cluster you want to configure>

kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.3/standard-install

helm repo add traefik https://traefik.github.io/charts
helm repo update traefik

helm upgrade traefik traefik/traefik \
  --namespace traefik \
  --version 41.0.0 \
  --reuse-values \
  --set providers.kubernetesGateway.enabled=true \
  --set gatewayClass.enabled=true \
  --set gateway.enabled=true \
  --set gateway.listeners.web.namespacePolicy.from=All \
  --wait

##############################################
# "Canary" deployment in the same namespace. #
##############################################

# Create a copy of a deployment with different name and no HTTPRoute resource.

apiVersion: apps/v1
kind: Deployment
metadata:
  name: caepe-webshop-demo-canary
spec:
  replicas: 1
  selector:
    matchLabels:
      app: caepe-webshop-demo-canary
  template:
    metadata:
      labels:
        app: caepe-webshop-demo-canary
    spec:
      containers:
        - name: caepe-webshop-demo-canary
          image: dsoadmin/caepe-webshop-demo:1.0
          imagePullPolicy: Always
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: caepe-webshop-demo-canary
spec:
  selector:
    app: caepe-webshop-demo-canary
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80

# Patch the "main" deployment route.

apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: caepe-webshop-demo
spec:
  parentRefs:
    - name: traefik-gateway
      namespace: traefik
      sectionName: web
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: caepe-webshop-demo
          port: 80
          weight: 50
        - name: caepe-webshop-demo-canary
          port: 80
          weight: 50

################################################
# "Canary" deployment in different namespaces. #
################################################

apiVersion: apps/v1
kind: Deployment
metadata:
  name: caepe-webshop-demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: caepe-webshop-demo
  template:
    metadata:
      labels:
        app: caepe-webshop-demo
    spec:
      containers:
        - name: caepe-webshop-demo
          image: dsoadmin/caepe-webshop-demo:1.0
          imagePullPolicy: Always
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: caepe-webshop-demo
spec:
  selector:
    app: caepe-webshop-demo
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
---
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: allow-different-namespace-route
spec:
  from:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      namespace: webshop # Should match the "main" deployment route namespace.
  to:
    - group: ""
      kind: Service
      name: caepe-webshop-demo

# Patch the "main" deployment route.

apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: caepe-webshop-demo
spec:
  parentRefs:
    - name: traefik-gateway
      namespace: traefik
      sectionName: web
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: caepe-webshop-demo
          port: 80
          weight: 50
        - name: caepe-webshop-demo
          namespace: webshop-canary # Should match the "canary" service namespace.
          port: 80
          weight: 50

#################################
# Testing canary traffic split. #
#################################

# Watch logs of both deployments.
# kubectl logs deployment/<main,canary> -n <namespace> -f

# port-forward to localhost:8080 and see the deployments logs - both should receive traffic.
kubectl port-forward service/traefik -n traefik 8080:80

```
