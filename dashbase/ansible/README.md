# Ansible Playbooks to deploy Dashbase agent

##### TO CONFIGURE DASHBASE AGNET #####

     0) Update value of "pushgateway_url" in deploy.yml with correct value.

     1) Update value of "proxy_url" in deploy.yml with correct host:port(port is default to `9200`).

     2) Create app specific "app_name_nw.yml" file and place it under roles/telegraf/templates/configs/<app_name_nw.yml>.

        Multiple paths can be specified in the same app_name.yml file:

       >cat roles/telegraf/templates/configs/syslog_nw.yml

        - paths: ["/var/log/syslog"]                          # path to the logs, can be glob pattern
          java_format: "yyyy-MM-dd HH:mm:ss"                  # format of the date of log entries - java_format
          zone: Local                                         # time zone, if Local, then machine time zone will be detected automatically
          exclude_files: ['_']                                # pattern to use to exclude files (optional parameter)

     3) Create app specific filebeat "yml" file and place it under roles/filebeat/templates/configs/<app_name.yml>

       >cat roles/filebeat/templates/configs/syslog.yml

        - type: log
          paths:
            - /var/log/syslog
          fields:
            _message_parser:
              type: grok
              pattern: '%{SYSLOGTIMESTAMP:timestamp} (?:%{SYSLOGFACILITY} )?%{SYSLOGHOST:logsource:meta} %{SYSLOGPROG}: %{GREEDYDATA:message}'
          multiline.pattern: ^\[
          multiline.negate: true
          multiline.match: after
          close_inactive: 90s
          harvester_limit: 5000
          scan_frequency: 1s
          symlinks: true
          clean_removed: true

##### TO DEPLOY DASHBASE AGENT #####

     0) Populate the inventory file, example:

       >cat inventory_syslog

        [syslog_hosts]
        192.168.131.98
        192.84.16.128

        ; See further configurations in https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html
        ; [syslog_hosts:vars]
        ; ansible_user=admin

     1) Run the playbook

       >ansible-playbook -i inventory_syslog deploy.yml -e "index=applogs app_name=syslog"

        Playbook takes these extra variables with -e (or will prompt for):

        index            - name of dashbase index to send logs to
        app_name         - name(s) of the applications (multiple app names can be given as a comma separated values)
