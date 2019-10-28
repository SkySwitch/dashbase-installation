# Ansible Playbooks to deploy Dashbase agent

##### TO CONFIGURE DASHBASE AGENT #####

     1) Create app specific filebeat "yml" file and place it under roles/filebeat/templates/configs>

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

     1) Populate the inventory file, example:

       >cat inventory

        [filebeat_hosts]
        192.168.131.98
        192.84.16.128

        ; See further configurations in https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html
        ; [filebeat_hosts:vars]
        ; ansible_user=admin

     2) Run the playbook

       >ansible-playbook -i inventory deploy.yml -e "dashbase_url=http://table-freeswitch.cluster1.dashbase.io:80 configs=syslog"

        Playbook takes these extra variables with -e (or will prompt for):

        dashbase_url     - URL of the dashbase table to send logs to (the http protocol and port are required)
        configs          - name(s) of the filebeat "yml" files without ".yml" (multiple values can be given as a comma separated list)
