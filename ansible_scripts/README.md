# Ansible Playbooks to deploy filebeat and telegraf

####### TO DEPLOY TELEGRAF ######

     0) update value of "pushgateway_url" in deploy_telegraf.yml with correct value

     1) populate the inventory file
        Example:

        >cat inventory_syslog


[syslog_hosts]
192.168.131.98
192.84.16.128


     2) create app specific "app_name_nw.yml" file and place it under roles/telegraf/templates/configs/<app_name_nw.yml>
  
       multiple paths can be specified in the same app_name_nw.yml file
       Example with two paths:

       >cat roles/telegraf/templates/configs/syslog_nw.yml


- paths: ["/var/log/syslog"]        # path to the logs, can be glob pattern
  java_format: "yyyy-MM-dd HH:mm:ss"                  # format of the date of log entries - java_format
  zone: Local                                         # time zone, if Local, then machine time zone will be detected automatically
  exclude_files: ['_']                                # pattern to use to exclude files (optional parameter)
 

     3) run the playbook

       >ansible-playbook -i inventory_syslog deploy_telegraf.yml -e "index=applogs app_name=syslog"

       Playbook takes these extra variables with -e (or will prompt for): 

       index            - name of dashbase index to send logs to 
       app_name         - name(s) of the applications (multiple app names can be given as a comma separated values)
 



###### TO DEPLOY FILEBEAT ######

     Filebeat deployment is almost identical to telegraf's. Please refer to examples above for inventory file
     and ansible-playbook extra variables

     0) update value of "proxy_url" in deploy_filebeat.yml with correct value

     1) populate the inventory file

     2) create app specific filebeat "yml" file and place it under roles/filebeat/templates/configs/<app_name.yml>
        Example of filebeat "yml" file with two paths:


- type: log
  paths:
    - /var/log/syslog
  fields:
    _message_parser:
      type: grok
      pattern: '%{SYSLOGTIMESTAMP:timestamp} (?:%{SYSLOGFACILITY} )?%{SYSLOGHOST:logsource:meta} %{SYSLOGPROG}: %{GREEDYDATA:message}'
    hostname: {{ ansible_hostname }}
  multiline.pattern: ^\[
  multiline.negate: true
  multiline.match: after
  close_inactive: 90s
  harvester_limit: 5000
  scan_frequency: 1s
  symlinks: true
  clean_removed: true

     3) run the playbook

       >ansible-playbook -i inventory_syslog deploy_filebeat.yml -e "index=applogs app_name=syslog"

