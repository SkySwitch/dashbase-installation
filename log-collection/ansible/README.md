To install logstash with mysql jdbc driver to fetch NetSapiens application logs:


Update the following parameters in deploy_logstash.yml to specify your connection_string, user name and password for mysql and table name to fetch data from:

      connection_string: jdbc:mysql://localhost:3306/database
      user: logstash
      password: logstash
      table: table_name

Create inventory file:
[logstash_hosts]
127.0.0.1

Run the playbook:

ansible-playbook -i inventory deploy_logstash.yml -e "dashbase_url=https://table-logs.<YOUR_SUBDOMAIN>:443 configs=netsapiens"

If you are running locally, you can use the same command with --connection local flag:
ansible-playbook -i inventory deploy_logstash.yml -e "dashbase_url=https://table-logs.<YOUR_SUBDOMAIN>:443 configs=netsapiens" --connection local


To install and configure SIP capture with heplify and add custom fields:

ansible-playbook -i inventory deploy.yml -e "dashbase_url=... configs=heplify"

[filebeat_hosts]
127.0.0.1

[filebeat:vars]
ansible_user=ubuntu
x-dashbase-application=test
x-dashbase-component=heplify
