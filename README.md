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
