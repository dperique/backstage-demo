# Running on minikube

Depending on your home setup, minikube may be a better Kubernetes to use (as Openshift Local can take up a lot of RAM).

Do this to deploy on minikube:

```bash
$ curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
$ sudo install minikube-linux-amd64 /usr/local/bin/minikube && rm minikube-linux-amd64
$ minikube start

$ cd minikube
kubectl delete configmap --ignore-not-found home-backstage-yamls
kubectl create configmap home-backstage-yamls --from-file=home_org.yaml

kubectl apply -f deployment.yaml
kubectl apply -f nodeport.yaml
kubectl port-forward svc/backstage-for-home 8080:7007
browse to localhost:7007
```