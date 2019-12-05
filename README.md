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

Run the installer, requires two arguments "submain" and optional "http"
example below

```
./dashbase-installer.sh raytest.dashbase.io http
```

WIP install script with input options

    --subdomain    provide subdomain field when expose via ingress
    --ingress      use ingress to expose web/tables; while default is using LB
    --nopresto     not include presto in the dashbase deployment
    --nossl        nossl deployment of dashbase, this option will skip presto
    
    
example of dashbase-installer-2.sh

    ./dashbase-installer-2.sh --subdomain=raytest.dashbase.io --ingress --nopresto --nossl --platform=aws
