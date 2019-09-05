# Ansible Playbooks to deploy Dashcomm Agent for FreeSWITCH (DAFS)

##### TO CONFIGURE DASHCOMM AGENT #####

     0) Update value of "pushgateway_url" in deploy.yml with correct value.

     1) Update value of "table_url" in deploy.yml with correct host:port(port is default to `9200`).

##### TO DEPLOY DASHCOMM AGENT #####

     0) Populate the inventory file, example:

        >cat inventory

        [freeswitch]
        192.168.131.98
        192.84.16.128

        ; See further configurations in https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html
        ; [freeswitch:vars]
        ; ansible_user=admin

     1) Run the playbook.

       >ansible-playbook -i inventory deploy.yml -e "index=freeswitch app_name=freeswitch"