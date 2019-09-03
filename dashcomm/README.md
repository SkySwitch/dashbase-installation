# Ansible Playbooks to deploy filebeat and telegraf

##### TO DEPLOY TELEGRAF #####

     0) update value of "pushgateway_url" in deploy_telegraf.yml with correct value

     1) populate the inventory file
        Example:

        >cat inventory
        
        [freeswitch]
        192.168.131.98
        192.84.16.128

     2) run the playbook

       >ansible-playbook -i inventory deploy_telegraf.yml -e "index=freeswitch app_name=freeswitch"

       Playbook takes these extra variables with -e (or will prompt for): 

       index            - name of dashbase index to send logs to 
       app_name         - name(s) of the applications (multiple app names can be given as a comma separated values)
 

##### TO DEPLOY FILEBEAT #####

     Filebeat deployment is almost identical to telegraf's. Please refer to examples above for inventory file
     and ansible-playbook extra variables

     0) update value of "table_url" in deploy_filebeat.yml with correct value

     1) populate the inventory file

     2) run the playbook

       >ansible-playbook -i inventory deploy_filebeat.yml -e "index=freeswitch app_name=freeswitch"

