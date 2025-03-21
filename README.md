# Docker API gateway

This demo shows how to setup a simple python Flask API that returns a message

uses Docker to build an image

uses Kind to setup a local cluster of containers

uses Kubernetes (kubectl) to manage the clusters (deploy the cluster and services) - used to scale up or down the amount of pods (containers)


## Build the docker image on your laptop using the laptops network


sudo su

    docker build --network=host -t api-gateway .

container is now available on your laptop

    root@mrxmini:# docker images

    REPOSITORY                     TAG             IMAGE ID       CREATED          SIZE
    api-gateway                         latest          688af556c1a8   15 seconds ago   136MB

run the container

    docker run -d -p 8500:8500 api-gateway

test your API

  curl http://localhost:8500  < should recieve message from python api


## Full setup instructions with local Cluster (for Prod deployement, see Production.md)

install Kind - local kuber cluster (for local development)

    curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/

create cluster with NodePort which allows external access

  ```
    cat <<EOF | kind create cluster --name local-cluster --config=-
        kind: Cluster
        apiVersion: kind.x-k8s.io/v1alpha4
        nodes:
        - role: control-plane
          extraPortMappings:
          - containerPort: 30080
            hostPort: 80
            protocol: TCP
        EOF
  ```

or create cluster with localhost access only

    kind create cluster --name local-cluster

build the Docker image

    docker build --network=host -t api-gateway:latest .

load the image into cluster

    kind load docker-image api-gateway:latest --name local-cluster


Install kubectl

      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      chmod +x kubectl
      mv kubectl /usr/bin/


create kube Deployment and Service

    kubectl apply -f kube/deployment.yaml
    kubectl apply -f kube/service.yaml


Get external IP (might take a minute to provision)

    kubectl get service api-gateway-service

if external access isnt working, port forward kind cluster to port 80 

    kubectl port-forward service/api-gateway-service 8500:80

Then curl the external IP

    curl http://<external-ip>

Should return: "hello from docker"

Test resilience, shut down 1 of 2 pods, (takes 1 min to terminate)

This scales down to 1 pod

    kubectl scale deployment api-gateway --replicas=1

Now terminate all pods, should be api gw service at all.

    kubectl scale deployment api-gateway --replicas=0

Horizontal scaling 

    # Scale the deployment
    kubectl scale deployment api-gateway --replicas=3

    # View logs
    kubectl logs -l app=api-gateway

    # Delete everything when done
    kubectl delete -f kube/service.yaml
    kubectl delete -f kube/deployment.yaml


## CHEATSHEET


### Docker Containers

stop a container

    docker ps (get container ID)
    docker stop $containerID (or by Name)

stop all running containers

    docker ps -a --format="{{.ID}}" | xargs docker stop


remove all containers

    docker rm $(docker ps -aq)

### Docker Images

see all images

    docker images

remove specific image

    docker rmi reponame:tag

remove all images

    docker rmi $(docker images -qa)


### Docker Network

get the Kind Cluster IP

    docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' local-cluster-control-plane

---

### Kind Cluster

create local test cluster

    kind create cluster --name local-cluster

show available clusters

    kind get clusters

delete all clusters
  
    kind delete clusters local-cluster

load local docker image into cluster
  
    kind load docker-image api-gateway:latest --name local-cluster

---

### Kubectl (Kubernetes - manages docker pod clusters)

    # Assuming you have kubectl configured

    kubectl apply -f kuber/deployment.yaml
    kubectl apply -f kuber/service.yaml

    # Check pods
    kubectl get pods

    # Check deployment
    kubectl get deployment

    # Check service
    kubectl get service


Here's what each part does:

    Deployment:
        Creates 2 replicas of your API gateway
        Uses your Docker image
        Specifies resource requests and limits
        Manages pod lifecycle

    Service:
        Exposes your API gateway pods
        Maps external port 80 to internal port 8500
        Uses LoadBalancer type to make it externally accessible

    # check service
    kubectl get service api-gateway-service

    # check which cluster kuber is talking to 
    kubectl cluster-info

    # show all running pods
    kubectl get pods

    # show pod specifics
    kubectl describe pod <pod name>

    # show pod logs 
    kubectl logs <pod name>

    # delete existing deployment and service
    kubectl delete -f kuber/service.yaml
    kubectl delete -f kuber/deployment.yaml

    # bring up new deployment and service
    kubectl apply -f kuber/deployment.yaml
    kubectl apply -f kuber/service.yaml
    
    # scale up or down
    kubectl scale deployment api-gateway --replicas=1
    kubectl scale deployment api-gateway --replicas=3

    # shut everything down in the namespace
    kubectl delete deployment,service --all

    # create custom Namespace
    kubectl create namespace api-gateway



## Kube Console

kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

kubectl proxy

Create a service account and get a token

kubectl -n kubernetes-dashboard create sa dashboard-admin
kubectl -n kubernetes-dashboard create clusterrolebinding dashboard-admin-binding --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard-admin
kubectl -n kubernetes-dashboard get secret $(kubectl -n kubernetes-dashboard get sa/dashboard-admin -o jsonpath="{.secrets[0].name}") -o go-template="{{.data.token | base64decode}}"

Open in your browser: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/