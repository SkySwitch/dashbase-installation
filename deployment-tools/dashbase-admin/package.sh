#!/usr/bin/env bash

BASEDIR=$(dirname "$0")
cd "$BASEDIR"/dashbase_setup_tarball && tar -cvf dashbase_setup_nolicy.tar *.sh *.yaml store_access_1 store_access_2 gce_mount_options aliyun_mount_options prometheus_webrtc
