#!/bin/bash
docker build -t dashbase/dashbase-admin .

cd dashbase_setup_tarball && tar -cvf dashbase_setup_nolicy.tar *.sh *.yaml store_access_1 store_access_2 gce_mount_options