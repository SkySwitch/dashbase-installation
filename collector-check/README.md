## Dashbase Collector status check script

The script "check_collector_status.sh" located in this folder is to check the following dashbase collector components

1. filebeat 
2. telegraf  
3. cronjob entry for sending metrics to pushgateway
4. filebeat, telegraf, pushgateway, port and URL

The script output will be shown on screen and appended to a file at /tmp/dashbase_collector_check.log

A sample ansible playbook "check_collector_playbook.yml" is used to deploy this script to the ansible host. Change this playbook for the "hosts:" entry that match with the inventory file. A sample output is shown below.

     Node: freeswitch-0.freeswitch.demo.svc.cluster.local  Timestamp: UTC_23:43:14-17-10-2019

    filebeat is running
      -- filebeat pid file exists
      -- filebeat process id  = 120915
      -- 1 filebeat command and 1 filebeat daemon are running
      -- number of errors in filebeat log file = 12 
      -- local filebeat URL http://localhost:1050 is accessible

    telegraf is running
      -- telegraf pid file exists
      -- telegraf process id  = 76443
      -- number of errors in telegraf.log file = 208 
      -- telegraf URL http://localhost:29273/metrics is accessible
      -- pushgateway URL http://pushgateway.dashcomm-demo.dashbase.io/metrics is accessible
      -- proxy URL http://table-freeswitch-0.table-   freeswitch.demo.svc.cluster.local:7888 is accessible

     cron daemon is running
     the cron job for push metrics to pushigateway is below
     * * * * * curl -s http://localhost:29273/metrics | curl --connect-timeout 10 --data-binary @- http://pushgateway.dashcomm-demo.dashbase.io/metrics/job/filebeat/instance/freeswitch-0 &> /dev/null
