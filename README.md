# Dashbase Installation

### Setup the installer

Download the dashbase-installer.sh script from this repo

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
./deployment-tools/update_license.sh --username=username --license=license
```

Upgrade dashbase version

Run upgrade-dashbase.sh script and specify dashbase version
```
./upgrade-dashbase.sh --version=1.0.2
``` 
options used on upgrade script

     --version        specify dashbase version
     --chartversion   optional entry for dashbase helm chart version, if missing will use default version in repo
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
