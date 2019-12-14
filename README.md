# Dashbase Installation

### Setup the installer

Download

```
curl https://raw.githubusercontent.com/dashbase/dashbase-installation/admin_installer/dashbase-installer.sh > dashbase-installer.sh
```

Give the installer permission
```
chmod +x dashbase-installer.sh
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
    --nopresto     not include presto in the dashbase deployment
    --nossl        nossl deployment of dashbase, this option will skip presto
    --exposemon    expose dashbase observibility tools: pushgateway, prometheus, grafana
    --valuefile    specify a custom dashbase value yaml file
                   e.g. --valuefile=/tmp/mydashbase_values.yaml
    
    
examples of using ingress, nopresto, nossl on AWS platform

    ./dashbase-installer.sh --subdomain=raytest.dashbase.io --ingress --nopresto --nossl --platform=aws
