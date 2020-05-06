### FreeSWITCH
This [folder](./resources) contains necessary Kubernetes resource files to set up a FreeSWITCH pod with mock data generated.

#### prerequisites
StorageClass:
    - dashbase-meta
    - dashbase-data

#### example usage
```shell script
./update-configuration.sh --es-hosts=https://table-freeswitch:7888 --namespace=default

./apply-freeswitch.sh --namespace=default

./remove-freeswitch.sh --namespace=default
```