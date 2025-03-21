# How to run a python API Gateway application as a microservice in Production with hi availability, scaling, TLS security 

Running your API gateway service in a production environment with `kubectl` on a Kubernetes cluster involves several considerations beyond local testing: high availability, scalability, security, external access, and resource management. I'll guide you through deploying your Python API gateway (from your earlier setup) to a production-ready Kubernetes cluster, assuming it’s hosted on a cloud provider (e.g., AWS EKS, GKE, AKS) or an on-premises cluster with a container registry. Here’s a step-by-step approach:

---

### Prerequisites
1. **Kubernetes Cluster**: A running production cluster (e.g., EKS, GKE, or self-managed).
2. **Container Registry**: A registry like Docker Hub, AWS ECR, or Google Container Registry to store your image (local images won’t work in a multi-node production cluster).
3. **kubectl**: Configured to communicate with your cluster (`kubectl config view` to check).
4. **Networking**: Ability to expose services externally (e.g., via a LoadBalancer or Ingress).

---

### Step 1: Prepare and Push the Docker Image
In production, you need to push your image to a registry accessible by the cluster.

1. **Build the Image**:
```bash
docker build -t your-registry/api-gateway:latest .
```
- Replace `your-registry` with your registry path (e.g., `myusername` for Docker Hub, or `123456789012.dkr.ecr.us-east-1.amazonaws.com` for AWS ECR).

2. **Log In to the Registry**:
```bash
docker login  # For Docker Hub
# Or for AWS ECR:
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
```

3. **Push the Image**:
```bash
docker push your-registry/api-gateway:latest
```

---

### Step 2: Define Production-Ready Manifests
Update your manifests for production with best practices like resource limits, health checks, and multiple replicas.

`deployment.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: default  # Or create a specific namespace
  labels:
    app: api-gateway
spec:
  replicas: 3  # High availability with 3 pods
  selector:
    matchLabels:
      app: api-gateway
  template:
    metadata:
      labels:
        app: api-gateway
    spec:
      containers:
      - name: api-gateway
        image: your-registry/api-gateway:latest
        imagePullPolicy: IfNotPresent  # Pull only if not cached
        ports:
        - containerPort: 8500
        resources:
          requests:
            cpu: "200m"    # 0.2 CPU cores
            memory: "256Mi"
          limits:
            cpu: "500m"    # 0.5 CPU cores
            memory: "512Mi"
        livenessProbe:    # Health check
          httpGet:
            path: /
            port: 8500
          initialDelaySeconds: 10
          periodSeconds: 30
        readinessProbe:   # Readiness check
          httpGet:
            path: /
            port: 8500
          initialDelaySeconds: 5
          periodSeconds: 10
```

`service.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: api-gateway-service
  namespace: default
spec:
  selector:
    app: api-gateway
  ports:
    - protocol: TCP
      port: 80        # External port
      targetPort: 8500 # Pod port
  type: LoadBalancer  # Exposes externally via cloud provider
```

---

### Step 3: Deploy to the Cluster
1. **Apply the Manifests**:
```bash
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

2. **Verify Deployment**:
```bash
kubectl get pods
kubectl get deployment api-gateway
```
- Ensure 3 pods are `Running`.

3. **Verify Service**:
```bash
kubectl get service api-gateway-service
```
- Wait for `EXTERNAL-IP` to populate (e.g., `a12b34c56.us-east-1.elb.amazonaws.com` on AWS).
- Test: `curl http://<external-ip>`

---

### Step 4: Production Enhancements
#### 1. Namespace
Use a dedicated namespace for organization:
```bash
kubectl create namespace api-gateway
# Update manifests with `namespace: api-gateway`
kubectl apply -f deployment.yaml -f service.yaml -n api-gateway
```

#### 2. Ingress (Optional)
For better routing and SSL, use an Ingress controller (e.g., NGINX):
`ingress.yaml`:
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway-ingress
  namespace: default
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-gateway-service
            port:
              number: 80
```
- Install an Ingress controller (e.g., `kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/cloud/deploy.yaml`).
- Apply: `kubectl apply -f ingress.yaml`.

#### 3. Autoscaling
Add a HorizontalPodAutoscaler (HPA):
`hpa.yaml`:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-gateway-hpa
  namespace: default
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-gateway
  minReplicas: 3
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```
Apply: `kubectl apply -f hpa.yaml`.

#### 4. Secrets (if needed)
For sensitive data (e.g., API keys):
```bash
kubectl create secret generic api-secrets --from-literal=key=value
# Mount in deployment under spec.template.spec.containers.env
```

---

### Step 5: Monitor and Manage
1. **Check Logs**:
```bash
kubectl logs -l app=api-gateway
```

2. **Scale Manually (if needed)**:
```bash
kubectl scale deployment api-gateway --replicas=5
```

3. **Rollout Updates**:
Update image and roll out:
```bash
kubectl set image deployment/api-gateway api-gateway=your-registry/api-gateway:v2
kubectl rollout status deployment/api-gateway
```

4. **Shutdown (if needed)**:
```bash
kubectl delete -f deployment.yaml -f service.yaml
```

---

### Production Notes
- **DNS**: Point a domain (e.g., `api.example.com`) to the `EXTERNAL-IP` or Ingress IP.
- **TLS**: Add SSL via Ingress annotations or a cert-manager.
- **Monitoring**: Integrate with tools like Prometheus/Grafana.
- **CI/CD**: Use a pipeline (e.g., GitHub Actions) to build/push images and apply manifests.

This setup gives you a robust, scalable API gateway in production. Test it with:
```bash
curl http://<external-ip>  # or https://api.example.com with Ingress
```
Should return "hello from docker". Let me know if you need help with any specific part!