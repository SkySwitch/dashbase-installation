# Get Started
In this repo, we've provided the basics for you to get started deploying Dashbase into an existing Kubernetes cluster and start ingesting logs.

## The Basics
A Dashbase cluster, at minimum, consists of the following:
- Dashbase Proxy Service (ingests and parses logs from Filebeat)
- Dashbase Table(s) (index and search)
- Dashbase Web UI (UI for troubleshooting)
- Dashbase API Service
- Etcd (cluster discovery)
- Apache Kafka (commit queue)
- Apache ZooKeeper (used by Kafka)

Everything is dockerized and is packaged using [Helm](https://github.com/helm/helm#helm-in-a-handbasket).

We slightly differ from the conventional Helm packages in that the base `values.yaml` that comes with our package is not meant to be modified. Instead, we require the user to provide their own `values.yaml` that describes their cluster, configured as needed for their deployment. You can see our templates by going to our K8s [repository](https://github.com/dashbase/dashbase-k8s/tree/master/dashbase).

## Install on your local machine
Want to first try out Dashbase on your laptop? Give the following steps a try, though note that we've only verified this to work on macOS.

### Requirements
- Docker Desktop with Kubernetes local cluster enabled. See Docker's [docs](https://docs.docker.com/docker-for-mac/#kubernetes) for details on how to get that set up.
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm](https://helm.sh/docs/using_helm/)

### Installation
1. Make sure your `kubectl` is configured for your local cluster.
    ```
    $ kubectl config current-context
    docker-for-desktop
    ```
2. Initialize Helm/Tiller on your cluster.
    ```bash
    $ helm init
    ```
3. Open up the `values.local.yaml` file with your favorite editor and put in your license information.
    ```yaml
    username: #your_username
    license: #your_license
    ```
4. Deploy Dashbase with this command:
    ```bash
    $ helm install dashbase --repo https://charts.dashbase.io --name dashbase --namespace dashbase -f values.local.yaml
    NAME:   dashbase
    LAST DEPLOYED: Tue Jun 25 15:48:48 2019
    NAMESPACE: dashbase
    STATUS: DEPLOYED

    RESOURCES:
    ==> v1/Pod(related)
    NAME                    READY  STATUS             RESTARTS  AGE
    api-694d9d546-q4d59     0/1    ContainerCreating  0         0s
    etcd-0                  0/1    Pending            0         0s
    grafana-0               0/1    ContainerCreating  0         0s
    kafka-0                 0/1    ContainerCreating  0         0s
    prometheus-0            0/1    Pending            0         0s
    proxy-748c9bf56b-htksf  0/1    ContainerCreating  0         0s
    table-logs-p0-0         0/1    Pending            0         0s
    web-0                   0/1    Pending            0         0s
    zookeeper-0             0/1    Pending            0         0s

    ==> v1/Service
    NAME                 TYPE       CLUSTER-IP      EXTERNAL-IP  PORT(S)            AGE
    api                  ClusterIP  10.106.71.134   <none>       8081/TCP,9876/TCP  0s
    etcd-cluster-client  ClusterIP  10.103.191.197  <none>       2379/TCP           0s
    grafana              ClusterIP  10.105.202.0    <none>       3000/TCP           0s
    kafka                ClusterIP  None            <none>       8080/TCP,9092/TCP  0s
    kafka-bootstrap      ClusterIP  10.111.96.111   <none>       9092/TCP           0s
    prometheus           ClusterIP  10.97.3.254     <none>       9090/TCP           0s
    proxy                ClusterIP  10.98.208.117   <none>       8081/TCP,9200/TCP  0s
    table-logs           ClusterIP  10.103.74.215   <none>       8081/TCP,7888/TCP  0s
    web                  ClusterIP  10.102.219.65   <none>       8081/TCP,8080/TCP  0s
    zookeeper            ClusterIP  10.106.120.126  <none>       8080/TCP,2181/TCP  0s

    ==> v1beta1/Deployment
    NAME   READY  UP-TO-DATE  AVAILABLE  AGE
    api    0/1    1           0          0s
    proxy  0/1    1           0          0s

    ==> v1beta1/Ingress
    NAME     HOSTS                                                                                    ADDRESS  PORTS  AGE
    ingress  grafana.127.0.0.1.xip.io,prometheus.127.0.0.1.xip.io,proxy.127.0.0.1.xip.io + 2 more...  80       0s

    ==> v1beta1/StatefulSet
    NAME           READY  AGE
    etcd           0/1    0s
    grafana        0/1    0s
    kafka          0/1    0s
    prometheus     0/1    0s
    table-logs-p0  0/1    0s
    web            0/1    0s
    zookeeper      0/1    0s
    ```
5. Periodically check and wait for all the pods to be in `Running` state.
    ```bash
    $ kubectl get pods --namespace dashbase
    NAME                                                     READY   STATUS              RESTARTS   AGE
    api-694d9d546-q4d59                                      1/1     Running             0          1m
    etcd-0                                                   1/1     Running             0          1m
    kafka-0                                                  1/1     Running             0          1m
    proxy-748c9bf56b-htksf                                   1/1     Running             0          1m
    table-logs-p0-0                                          1/1     Running             0          1m
    web-0                                                    1/1     Running             0          1m
    zookeeper-0                                              1/1     Running             0          1m
    ```

6. Deploy an [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/) so you can access the services without having to port-forward or other shinanigans.
    ```bash
    helm install stable/nginx-ingress --name ingress --namespace dashbase
    ```
    We've already pre-configured the Kubernetes Ingress resource for you, so you can get the full list of available endpoints by describing the ingress.
    ```bash
    $ kubectl describe ingress
    Name:             ingress
    Namespace:        dashbase
    Address:
    Default backend:  default-http-backend:80 (<none>)
    Rules:
      Host                         Path  Backends
      ----                         ----  --------
      proxy.127.0.0.1.xip.io
                                      proxy:9200 (10.1.0.192:9200)
      web.127.0.0.1.xip.io
                                      web:8080 (10.1.0.193:8080)
      table-logs.127.0.0.1.xip.io
                                      table-logs:7888 (10.1.0.194:7888)
    Annotations:
      kubernetes.io/ingress.class:                  nginx
      nginx.ingress.kubernetes.io/proxy-body-size:  64m
    Events:
      Type    Reason  Age    From                      Message
      ----    ------  ----   ----                      -------
      Normal  CREATE  9m33s  nginx-ingress-controller  Ingress default/ingress
      Normal  UPDATE  8m41s  nginx-ingress-controller  Ingress default/ingress
    ```

7. Start a Filebeat on your local machine using the provided `filebeat.yml` config to produce some logs to the table. 

8. Go to the [Dashbase Web UI](http://web.127.0.0.1.xip.io) to search over those logs. Note that there's no parsing configured, so by default we use the harvest time as the timestamp for the event. The original event's timestamp is within the `message` field.

## Install on AWS

### Requirements
- A Kubernetes cluster running on AWS with a minimum of the following worker nodes:
  - 2 c5.xlarge
  - 1 r5.xlarge
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [Helm](https://helm.sh/docs/using_helm/)

### Installation

## Cleanup
1. List and remove the helm release.
    ```bash
    $ helm list
    NAME    	REVISION	UPDATED                 	STATUS  	CHART              	APP VERSION	NAMESPACE
    dashbase	1       	Wed Jun 26 11:25:15 2019	DEPLOYED	dashbase-0.21.0    	0.21.0     	dashbase
    ingress 	1       	Wed Jun 26 11:25:33 2019	DEPLOYED	nginx-ingress-1.7.0	0.24.1     	dashbase

    $ helm delete dashbase ingress --purge
    release "dashbase" deleted
    release "ingress" deleted
    ```
2. You'll also have to clean up the Persistent Volume Claims that were created, either by deleting them individually or by deleting the entire namespace that Dashbase was deployed to (if possible).
    ```bash
    $ kubectl get pvc --namespace dashbase
    NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                                         STORAGECLASS   REASON   AGE
    pvc-391477d5-97a2-11e9-8875-025000000001   10Gi       RWO            Delete           Bound    dashbase/elasticsearch-data-elasticsearch-0   hostpath                18h
    pvc-cc7524d3-979f-11e9-8875-025000000001   10Gi       RWO            Delete           Bound    dashbase/etcd-data-etcd-0                     hostpath                19h
    pvc-cc7cf3ae-979f-11e9-8875-025000000001   10Gi       RWO            Delete           Bound    dashbase/zookeeper-data-zookeeper-0           hostpath                19h
    pvc-cc8307c2-979f-11e9-8875-025000000001   10Gi       RWO            Delete           Bound    dashbase/grafana-data-grafana-0               hostpath                19h
    pvc-cc93b28e-979f-11e9-8875-025000000001   10Gi       RWO            Delete           Bound    dashbase/web-data-web-0                       hostpath                19h
    pvc-ccc1c136-979f-11e9-8875-025000000001   10Gi       RWO            Delete           Bound    dashbase/prometheus-data-prometheus-0         hostpath                19h
    pvc-ccd633ba-979f-11e9-8875-025000000001   10Gi       RWO            Delete           Bound    dashbase/table-data-table-logs-p0-0           hostpath                19h
    pvc-ccd9d286-979f-11e9-8875-025000000001   500Gi      RWO            Delete           Bound    dashbase/kafka-data-kafka-0                   hostpath                19h

    # Note: you can pass more than one pvc to the delete command.
    $ kubectl delete pvc elasticsearch-data-elasticsearch-0
    persistentvolumeclaim "elasticsearch-data-elasticsearch-0" deleted
    ```

    ```bash
    $ kubectl get namespaces
    NAME          STATUS   AGE
    dashbase      Active   19h
    default       Active   91d
    docker        Active   91d
    kube-public   Active   91d
    kube-system   Active   91d

    $ kubectl delete namespace dashbase
    namespace "dashbase" deleted

    $ kubectl get pvc
    No resources found.
    ```