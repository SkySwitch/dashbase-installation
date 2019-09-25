## How to Deploy Dashcomm Agent for FreeSWITCH (DAFS) with standalone configs

Here're there configuration files needed for DAFS.
* [filebeat.yml](filebeat.yml) Filebeat configuration for collecting logs on your hosts.
* [freeswitch-nw.yml](freeswitch-nw.yml) Night-Watch configuration for log stats on your hosts.
* [telegraf.conf](telegraf.conf) Telegraf configuration for gathering night-watch and Filebeat metrics on your hosts.

### Filebeat

#### Installation
Filebeat is required to collect logs, you can set it up with the following steps:
1. Get the Filebeat installation package [deb](../ansible/roles/filebeat/files/filebeat-6.6.2-amd64.deb) and [rpm](../ansible/roles/filebeat/files/filebeat-6.6.2-x86_64.rpm) in this repo.
2. Install Filebeat on your host. (Verify by executing `filebeat` command)
3. Copy the [filebeat.yml](filebeat.yml) to `/etc/filebeat/filebeat.yml` on your host. (or someplace your Filebeat can access).
4. Launch Filebeat on your host via `filebeat -c /etc/filebeat/filebeat.yml -path.home /usr/share/filebeat -path.config /etc/filebeat -path.data /var/lib/filebeat -path.logs /var/log/filebeat`. Make sure your Filebeat have permissions to access these directories.
5. Verify Filebeat running well by tailing logs `tail -f /var/log/filebeat/filebeat`.

#### Required Configure in [filebeat.yml](filebeat.yml)
**You need to point `output.elasticsearch.hosts` to your Dashbase table.**

#### Advanced Configure in [filebeat.yml](filebeat.yml)
* You can change `output.elasticsearch.protocol` if needed.
* You can change `filebeat.prospectors[0].paths` if you have a custom path storing FreeSWITCH logs.
* You can configure `filebeat.prospectors[0].multiline` section following [Filebeat guide](https://www.elastic.co/guide/en/beats/filebeat/6.6/multiline-examples.html) if you have custom formatted logs in your FreeSWITCH.
* You can configure `filebeat.prospectors[0].fields._message_parser` section following [Dashbase guide](https://dashbase.atlassian.net/wiki/spaces/DK/pages/6816075/Parser+Reference) if you have custom formatted logs in your FreeSWITCH. (Usually, you don't need to modify it because there was already a default pattern to parse various kinds of logs)

### Night-Watch

#### Installation
Night-Watch is required to logs stats, you can set it up with the following steps:
1. Get the night-watch installation package [deb](../ansible/roles/telegraf/files/night-watch_1.1.1-rc4_Linux_64-bit.deb) and [rpm](../ansible/roles/telegraf/files/night-watch_1.1.1-rc4_Linux_64-bit.rpm) in this repo.
2. Install night-watch on your host. (Verify by executing `night-watch` command)
3. Copy the [freeswitch-nw.yml](freeswitch-nw.yml) to `/etc/telegraf/configs/freeswitch_nw.yml` on your host.

**Night-Watch is directly used by Telegraf, you can regard the installation as done when you can use `night-watch` command and the config file is present.**

#### Advanced Configure in [freeswitch-nw.yml](freeswitch-nw.yml)
* You can change `paths` if you have a custom path storing FreeSWITCH logs.

### Telegraf
Telegraf is required to gather metrics from night-watch and Filebeat, you can set it up with the following steps:
1. Get the Telegraf installation package [deb](../ansible/roles/telegraf/files/telegraf_1.10.4-1_amd64.deb) and [rpm](../ansible/roles/telegraf/files/telegraf-1.10.4-1.x86_64.rpm) in this repo.
2. Install Telegraf on your host. (Verify by executing `telegraf` command)
3. Copy the [telegraf.conf](telegraf.conf) to `/etc/telegraf/telegraf.conf` on your host. (or someplace your Telegraf can access).
4. Launch Telegraf on your host via `telegraf -pidfile /var/run/telegraf/telegraf.pid -config /etc/telegraf/telegraf.conf`. Make sure your Telegraf have permissions to access these files.
5. Verify Telegraf running well by tailing logs `tail -f /var/log/telegraf/telegraf.log` and curling metrics path which was defined in its config `curl -s http://localhost:29273/metrics`.

### Push metrics to PushGateway
The last step is to push your Telegraf exposed metrics to PushGateway.
Add this line to cron jobs and change the <pushgateway_host> to your own. ($HOSTNAME will convert to your local hostname automatically)
```bash
* * * * * curl -s http://localhost:29273/metrics | curl --connect-timeout 10 --data-binary @- http://<pushgateway_host>/metrics/job/filebeat/instance/$HOSTNAME &> /dev/null
```