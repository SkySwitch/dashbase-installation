# Dashbase Installation

### Setup the installer

Download the dashbase-installer.sh script from this repo

General assumption to use this dashbase-installer.sh script
```
 1. You have setup K8s cluster
 2. Your workstation has kubectl command installed and able to access to K8s cluster

```

Give the installer permission
```
chmod a+x dashbase-installer.sh
```

Run the installer, the only required input is platform flag
example below is to create dashbase installation, with internal https, secure presto, and expose web/tables endpoints in LB.

```
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
    
    
examples of using ingress, on AWS platform

    ./dashbase-installer.sh --subdomain=raytest.dashbase.io --ingress --platform=aws

The standard installation requires minium 3 nodes with 8 CPU, and 64 GB Ram per node.

For internal testing installation 
For smaller setup such as 3 X t3.medium ( 3 X  2cpu + 4GB ram), use the dashbase-installer-smallsetup.sh inside the deployment-tools folder

```
./dashbase-installer-smallsetup.sh --platform=aws
```

Update dashbase license with username and license 

```
username: "username"
license: "license"
```

Run update_license.sh, with username and license. **Don't need ""**
```
./deployment-tools/upgrade-dashbase.sh --username=username --license=license
```

Upgrade dashbase version

Run upgrade-dashbase.sh script and specify dashbase version
```
./upgrade-dashbase.sh --version=1.0.2
``` 
options used on upgrade script

     --version        specify dashbase version
     --chartversion   optional entry for dashbase helm chart version, if missing will match with dashbase version
     --username       username for license information
     --license        dashbase license string


To undo the dashbase installation on K8s cluster

```
Download the script uninstall_dashbase.sh 

chmod a+x uninstall_dashbase.sh

./uninstall_dashbase.sh
```

Install log file is saved in your current directory when running the script, the install log will capture all screen output and with filename like below:
```
 dashbase_install_`date +%d-%m-%Y_%H-%M-%S`.log
```

### Setup K8s cluster on AWS (EKS Cluster)
The create-aws-eks.sh script provides an easy way to create a basic AWS EKS cluster for dashbase installation purpose
You can use this script to setup AWS EKS cluster and install dashbase at the same time.
By default, the script will create an EKS cluster on us-east-2a with three worker nodes of size R5.2xlarge
Download the create-aws-eks.sh script and input your AWS Access Key as shown from following examples
** The following AWS key and secrets are just samples, please your own key and secrets from your account **

```
chmod a+x create-aws-eks.sh

# Create AWS EKS cluster in default us-east-2a

./create-aws-eks.sh --aws_access_key=AKIA6GHKI73ZYYN4566D --aws_secret_access_key=kqoQl8nH/tJ1INg6UVOv39+5TK2eJLCqwK+3a9jj

# Create AWS EKS cluster in defautl us-east-2a and install dashbase with default options

./create-aws-eks.sh --aws_access_key=AKIA6GHKI73ZYYN4566D --aws_secret_access_key=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 --install_dashbase

# Create AWS EKS cluster in us-west-2a and install dashbase with default options

./create-aws-eks.sh --aws_access_key=AKIA6GHKI73ZYYN4566D --aws_secret_access_key=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 --region=us-west-1 --install_dashbase
```

Options for the EKS cluster creation script

      --aws_access_key          AWS Access Key ID
      --aws_secret_access_key   AWS Secret Access Key
      --region                  AWS region e.g. us-east-2 or us-west-2 
                                Please check available regions allow EKS cluster
      --instance_type           Default use R5.2xlarge if not specified
      --node_number             Number of worker nodes, and dfault is three
      --cluster_name            Specify custom EKS cluster name, and default is mydash<RANDOM_STRING>
      --install_dashbase        Install dashbase with default options after EKS cluster is ready
      --small_setup             Create a three nodes with t2.medium instance type, for testing purpose only
      
       
### Create or recreate docker-helper container after installation

When using the create-aws-eks.sh script to setup AWS EKS cluster and install dashbase;  the script will create a docker-helper container on your workstation.
The function of docker-helper is have AWS CLI be configured so we can use "aws eks " or "eksctl" command to create the cluster. However, when this docker-helper container is exited or deleted, you can recreate it using create-docker-helper.sh script. The following shows some  examples to run the create-docker-helper.sh script.

```

# Create docker-helper container and input new AWS access keys

./create-docker-helper.sh --aws_access_key=AKIA6GHKI73ZYYN4566D --aws_secret_access_key=kqoQl8nH/tJ1INg6UVOv39+5TK2eJLCqwK+3a9jj --region=us-west-2

# Re-create docker-helper container after dashbase installation, assume your docker-helper container deleted or restarted. You don't need to enter AWS access keys, the script will find the previous AWS access key and region.

./create-docker-helper.sh 

```

Options for create-docker-helper.sh

      --aws_access_key          AWS Access Key ID
      --aws_secret_access_key   AWS Secret Access Key
      --region                  AWS region e.g. us-east-2 or us-west-2
                                Please check available regions allow EKS cluster


