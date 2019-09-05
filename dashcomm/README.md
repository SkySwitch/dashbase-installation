### Dashcomm

#### Create a new k8s cluster on aws (k8s version>1.11.0)

This eks cluster requires one `r5.2xlarge` for dashbase-table and one `m5.xlarge` to dashbase-core services.

The following steps assuming you have provision the k8s cluster with `helm`, `kubectl` already installed locally.

1. Provision Helm

   ```bash
   helm init --upgrade
   kubectl create serviceaccount --namespace kube-system tiller
   kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
   kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
   ```

2. Install Ingress controller and configure dns.

   You need install nginx ingress controller and get External-IP-Address from ingress.

   ```bash
   helm install stable/nginx-ingress --name {your_ingress_name}
   kubectl --namespace default get services -o wide -w {your_ingress_name}-nginx-ingress-controller
   ```

   Bind all your ingress services into aws route-53

   If you have a domian `k8s.yourcompany.com` and you got an external-IP `acec462704f65d0ab332d-86962061.us-west-2.elb.amazonaws.com` you should bind `*.k8s.yourcompany.com` to `acec462704f65d0ab332d-86962061.us-west-2.elb.amazonaws.com` using `alias`. And then, wait the DNS taking effect.

3. Prepare the values.yml

   Change the username/license fields to your dashbase username/license and change `dashbase.ingress.host` to the domain you bind.(e.g. `k8s.yourcompany.com` in the above example).

   ```bash
   dashbase:
     ingress:
       enabled: true
       host: k8s.yourcompany.com
     username: username
     license: license
   ```

4. Install Dashbase

   ```bash
   helm repo add chartmuseum https://charts.dashbase.io
   helm upgrade dashcomm chartmuseum/dashcomm -f dashcomm.yml -i
   ```

#### Configure FreeSWITCH

Configure FreeSWITCH machines' default user have permission to use `sudo` and can access FreeSWITCH's log dir.

#### Deploy Ansible & Filebeat 

Go ahead to [Deploy Ansible & Filebeat](ansible/README.md)