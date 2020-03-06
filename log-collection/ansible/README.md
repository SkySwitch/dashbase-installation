How to enable heplify and add custom fields:

ansible-playbook -i inventory deploy.yml -e "dashbase_url=... configs=heplify"

[filebeat]
127.0.0.1

[filebeat:vars]
ansible_user=ubuntu
x-dashbase-application=test
x-dashbase-component=heplify
