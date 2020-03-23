# Dashbase Installation

### AWS only: Create EKS cluster and install Dashbase:

```
   1. create a t2.micro EC2 instance with CentOS 7.4  (e.g. ami-0df65459f2f119903 on us-west-2) that will be used as cluster admin host.
   2. once the EC2 is up, ssh to the EC2 and become root.
   3. inside the EC2, run the following commands:
      ** Remember to change the AWS access key and secret, region and subdomain below

      git clone https://github.com/dashbase/dashbase-installation.git
      cd dashbase-installation/

      ./aws_eks_dashbase_install.sh  --aws_access_key=YOURAWSACCESSKEY \
                                     --aws_secret_access_key=YOURACESSSECRETACCESSKEY \
                                     --region=YOURREGION --subdomain=YOURSUBDOMAIN --install_dashbase
                                     
     
     Enable basic auth when installing dashbase during EKS cluster setup
     --basic_auth
     --authusername
     --authpassword
  
     ./aws_eks_dashbase_install.sh  --aws_access_key=YOURAWSACCESSKEY \
                                     --aws_secret_access_key=YOURACESSSECRETACCESSKEY \
                                     --region=YOURREGION --subdomain=YOURSUBDOMAIN --install_dashbase \
                                     --basic_auth
                                     --authusername=admin
                                     --authpassword=dashbase
      

```
This will create EKS cluster with two r5.xlarge nodes in the region specified and install dashbase on this cluster.

Installation process saves progress information into log file in current working directory:
```
 dashbase_install_`date +%d-%m-%Y_%H-%M-%S`.log
```

At the end of installation process, ingress controller IP will be provided.
Create Record Set mapping from ingress controller IP to subdomain using AWS Route 53.
After that, endpoints to access Dashbase Web UI, Dashbase table for indexing and Dashbase grafana for monitoring can be accessed.


### AWS only: Uninstall Dashbase and delete EKS cluster and all cluster-related resources:

Run remove_aws_eks.sh script with --region parameter.
It will find EKS dashbase cluster in that region and delete it.

```
cd dashbase-installation/
deployment-tools/remove_aws_eks.sh --region=REGION
```

### AWS, GCE, AZURE: Install Dashbase on already created K8s cluster:

Pre-reqs:
```
 1. You have K8s cluster with minimum 2 nodes of r5.xlarge or equivalent
 2. You have kubectl command installed and able to access K8s cluster
 3. You cloned Dashbase installation repository with:
    git clone https://github.com/dashbase/dashbase-installation.git
```

Run the installer with --platform flag provided (mandatory)
It will install dashbase with internal https, secure presto, and expose web/tables endpoints in LB.

```
cd dashbase-installation/
./dashbase-installer.sh --platform=aws
```

install script options

    --platform     aws or azure or gce
    --subdomain    provide subdomain field when expose via ingress and is required to have ingress flag be present
                   e.g.  --subdomain=mydomain.bigdomain.io
    --version      specify a version if not nightly will be used
                   e.g. --version=1.0.1
    --ingress      use ingress to expose web/tables; while default is using LB

    --exposemon    expose dashbase observibility tools: pushgateway, prometheus
    --valuefile    specify a custom dashbase value yaml file
                   e.g. --valuefile=/tmp/mydashbase_values.yaml
    --username     username for license information 
                   e.g. --username=scott
    --license      dashbase license string 
                   e.g. --license=Aertyujk8903HJKLBNMLOP34erTui
    --basic_auth   enable basic authentication via default ingress controller
    --authusername basic auth username
                   e.g. --authusername=
    
    
examples of using ingress, on AWS platform

    ./dashbase-installer.sh --subdomain=raytest.dashbase.io --ingress --platform=aws

The standard installation requires minium 2 nodes with 8 CPU, and 64 GB Ram per node.

For smaller setup such as 2 X r5.xlarge 2 X (4cpu + 32GB ram), use the dashbase-installer-smallsetup.sh inside the deployment-tools folder

```
./deployment-tools/dashbase-installer-smallsetup.sh --platform=aws
```

### Update dashbase license

```
./deployment-tools/upgrade-dashbase.sh --username=username --license=license
```

### Upgrade dashbase version

Run upgrade-dashbase.sh script and specify dashbase version
```
./deployment-tools/upgrade-dashbase.sh --version=1.2.0
``` 
options used on upgrade script

     --version        specify dashbase version
     --chartversion   optional entry for dashbase helm chart version, if missing will match with dashbase version
     --username       username for license information
     --license        dashbase license string



