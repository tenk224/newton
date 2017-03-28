#!/bin/bash

ipadd=$1
ifname=$2

#----------------------------------------------------------------------------------
yum install mariadb mariadb-server python2-PyMySQL \
rabbitmq-server \
memcached python-memcached \
openstack-keystone httpd mod_wsgi \
openstack-glance \
openstack-nova-api openstack-nova-conductor \
openstack-nova-console openstack-nova-novncproxy \
openstack-nova-scheduler \
openstack-neutron openstack-neutron-ml2 \
openstack-neutron-linuxbridge ebtables \
openstack-dashboard \
expect -y
#----------------------------------------------------------------------------------
systemctl enable rabbitmq-server.service
systemctl start rabbitmq-server.service

rabbitmqctl add_user openstack 123456
rabbitmqctl set_permissions openstack ".*" ".*" ".*"
#----------------------------------------------------------------------------------
cat > /etc/my.cnf.d/openstack.cnf <<EOF
[mysqld]
bind-address = $ipadd

default-storage-engine = innodb
innodb_file_per_table
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
EOF

systemctl enable mariadb.service
systemctl start mariadb.service

spawn mysql_secure_installation
expect {Enter current password for root (enter for none):}
send "\r"
expect {Change the root password?}
send "Y\r"
expect {New password:}
send "123456\r"
expect {Re-enter new password:}
send "123456\r"
expect {Remove anonymous users?}
send "Y\r"
expect {Disallow root login remotely?}
send "Y\r"
expect {Remove test database and access to it?}
send "Y\r"
expect {Reload privilege tables now?}
send "Y\r"
expect eof

mysql -u "root" "-p123456" < ./db.sql
#----------------------------------------------------------------------------------
cat > /etc/sysconfig/memcached <<EOF
PORT="11211"
USER="memcached"
MAXCONN="1024"
CACHESIZE="64"
OPTIONS="-l $ipadd,::1"
EOF

systemctl enable memcached.service
systemctl start memcached.service
#----------------------------------------------------------------------------------
sed -i "/^\[database\]$/a connection = mysql+pymysql://keystone:123456@controller/keystone" /etc/keystone/keystone.conf

sed -i "/^\[token\]$/a provider = fernet" /etc/keystone/keystone.conf

su -s /bin/sh -c "keystone-manage db_sync" keystone

keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

keystone-manage bootstrap --bootstrap-password 123456 \
  --bootstrap-admin-url http://controller:35357/v3/ \
  --bootstrap-internal-url http://controller:35357/v3/ \
  --bootstrap-public-url http://controller:5000/v3/ \
  --bootstrap-region-id RegionOne

sed -i "/^#ServerName www.example.com:80$/a ServerName controller" /etc/httpd/conf/httpd.conf

ln -s /usr/share/keystone/wsgi-keystone.conf /etc/httpd/conf.d/
systemctl enable httpd.service
systemctl start httpd.service

openstack project create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--domain default --description "Service Project" service

openstack project create --domain default \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--description "Demo Project" demo

openstack user create --domain default \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--password 123456 demo

openstack role create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
user

openstack role add \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--project demo --user demo user

openstack \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name demo \
--os-username demo \
--os-password 123456 \
--os-auth-url http://controller:5000/v3 \
--os-identity-api-version 3 \
token issue

openstack \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
token issue

openstack user create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--domain default --password 123456 glance

openstack role add \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--project service --user glance admin

openstack service create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--name glance --description "OpenStack Image" image

openstack endpoint create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--region RegionOne image public http://controller:9292

openstack endpoint create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--region RegionOne image internal http://controller:9292

openstack endpoint create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--region RegionOne image admin http://controller:9292

openstack user create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--domain default --password 123456 nova

openstack role add \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--project service --user nova admin

openstack service create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--name nova --description "OpenStack Compute" compute

openstack endpoint create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--region RegionOne compute public http://controller:8774/v2.1/%\(tenant_id\)s

openstack endpoint create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--region RegionOne compute internal http://controller:8774/v2.1/%\(tenant_id\)s

openstack endpoint create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--region RegionOne compute admin http://controller:8774/v2.1/%\(tenant_id\)s

openstack user create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--domain default --password 123456 neutron

openstack role add \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--project service --user neutron admin

openstack service create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--name neutron --description "OpenStack Networking" network

openstack endpoint create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--region RegionOne network public http://controller:9696

openstack endpoint create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
--region RegionOne network internal http://controller:9696

openstack endpoint create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
 --region RegionOne network admin http://controller:9696

cat > admin-openrc <<EOF
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=123456
export OS_AUTH_URL=http://controller:35357/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

cat > demo-openrc <<EOF
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=demo
export OS_USERNAME=demo
export OS_PASSWORD=123456
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF
#----------------------------------------------------------------------------------
sed -i "/^\[database\]$/a connection = mysql+pymysql://glance:123456@controller/glance" /etc/glance/glance-api.conf

sed -i "/^\[keystone_authtoken\]$/a auth_uri = http://controller:5000\n\
auth_url = http://controller:35357\n\
memcached_servers = controller:11211\n\
auth_type = password\n\
project_domain_name = Default\n\
user_domain_name = Default\n\
project_name = service\n\
username = glance\n\
password = 123456" /etc/glance/glance-api.conf

sed -i "/^\[paste_deploy\]$/a flavor = keystone" /etc/glance/glance-api.conf

sed -i "/^\[glance_store\]$/a stores = file,http\n\
default_store = file\n\
filesystem_store_datadir = /var/lib/glance/images/" /etc/glance/glance-api.conf

sed -i "/^\[database\]$/a connection = mysql+pymysql://glance:123456@controller/glance" /etc/glance/glance-registry.conf

sed -i "/^\[keystone_authtoken\]$/a auth_uri = http://controller:5000\n\
auth_url = http://controller:35357\n\
memcached_servers = controller:11211\n\
auth_type = password\n\
project_domain_name = Default\n\
user_domain_name = Default\n\
project_name = service\n\
username = glance\n\
password = 123456" /etc/glance/glance-registry.conf

sed -i "/^\[paste_deploy\]$/a flavor = keystone" /etc/glance/glance-registry.conf

su -s /bin/sh -c "glance-manage db_sync" glance
systemctl enable openstack-glance-api.service openstack-glance-registry.service
systemctl start openstack-glance-api.service openstack-glance-registry.service
#----------------------------------------------------------------------------------
sed -i "/^\[DEFAULT\]$/a enabled_apis = osapi_compute,metadata\n\
transport_url = rabbit://openstack:123456@controller\n\
auth_strategy = keystone\n\
my_ip = $ipadd\n\
use_neutron = True\n\
firewall_driver = nova.virt.firewall.NoopFirewallDriver" /etc/nova/nova.conf

sed -i "/^\[api_database\]$/a connection = mysql+pymysql://nova:123456@controller/nova_api" /etc/nova/nova.conf

sed -i "/^\[database\]$/a connection = mysql+pymysql://nova:123456@controller/nova" /etc/nova/nova.conf

sed -i "/^\[keystone_authtoken\]$/a auth_uri = http://controller:5000\n\
auth_url = http://controller:35357\n\
memcached_servers = controller:11211\n\
auth_type = password\n\
project_domain_name = Default\n\
user_domain_name = Default\n\
project_name = service\n\
username = nova\n\
password = 123456" /etc/nova/nova.conf

sed -i "/^\[vnc\]$/a vncserver_listen = $my_ip\n\
vncserver_proxyclient_address = $my_ip" /etc/nova/nova.conf

sed -i "/^\[glance\]$/a api_servers = http://controller:9292" /etc/nova/nova.conf

sed -i "/^\[oslo_concurrency\]$/a lock_path = /var/lib/nova/tmp" /etc/nova/nova.conf

su -s /bin/sh -c "nova-manage api_db sync" nova
su -s /bin/sh -c "nova-manage db sync" nova

systemctl enable openstack-nova-api.service \
openstack-nova-consoleauth.service openstack-nova-scheduler.service \
openstack-nova-conductor.service openstack-nova-novncproxy.service

systemctl start openstack-nova-api.service \
openstack-nova-consoleauth.service openstack-nova-scheduler.service \
openstack-nova-conductor.service openstack-nova-novncproxy.service
#----------------------------------------------------------------------------------
sed -i "/^\[database\]$/a connection = mysql+pymysql://neutron:123456@controller/neutron" /etc/neutron/neutron.conf

sed -i "/^\[DEFAULT\]$/a core_plugin = ml2
service_plugins =
transport_url = rabbit://openstack:123456@controller
auth_strategy = keystone
notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True" /etc/neutron/neutron.conf

sed -i "/^\[keystone_authtoken\]$/a auth_uri = http://controller:5000
auth_url = http://controller:35357
memcached_servers = controller:11211
auth_type = password
project_domain_name = Default
user_domain_name = Default
project_name = service
username = neutron
password = 123456" /etc/neutron/neutron.conf

sed -i "/^\[nova\]$/a auth_url = http://controller:35357
auth_type = password
project_domain_name = Default
user_domain_name = Default
region_name = RegionOne
project_name = service
username = nova
password = 123456" /etc/neutron/neutron.conf

sed -i "/^\[oslo_concurrency\]$/a lock_path = /var/lib/neutron/tmp" /etc/neutron/neutron.conf

sed -i "/^\[ml2\]$/a type_drivers = flat,vlan" /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i "/^\[ml2\]$/a tenant_network_types =" /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i "/^\[ml2\]$/a mechanism_drivers = linuxbridge" /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i "/^\[ml2\]$/a extension_drivers = port_security" /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i "/^\[securitygroup\]$/a enable_ipset = True" /etc/neutron/plugins/ml2/ml2_conf.ini
sed -i "/^\[ml2_type_flat\]$/a flat_networks = provider" /etc/neutron/plugins/ml2/ml2_conf.ini

sed -i "/^\[linux_bridge\]$/a physical_interface_mappings = provider:$ifname" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i "/^\[securitygroup\]$/a enable_security_group = False\n\
firewall_driver = neutron.agent.firewall.NoopFirewallDriver" /etc/neutron/plugins/ml2/linuxbridge_agent.ini
sed -i "/^\[vxlan\]$/a enable_vxlan = False" /etc/neutron/plugins/ml2/linuxbridge_agent.ini

sed -i "/^\[DEFAULT\]$/a einterface_driver = neutron.agent.linux.interface.BridgeInterfaceDriver\n\
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq\n\
enable_isolated_metadata = True" /etc/neutron/dhcp_agent.ini

sed -i "/^\[DEFAULT\]$/a nova_metadata_ip = controller\n\
metadata_proxy_shared_secret = 123456" /etc/neutron/metadata_agent.ini

sed -i "/^\[neutron\]$/a url = http://controller:9696\n\
auth_url = http://controller:35357\n\
auth_type = password\n\
project_domain_name = default\n\
user_domain_name = default\n\
region_name = RegionOne\n\
project_name = service\n\
username = neutron\n\
password = 123456\n\
\n\
service_metadata_proxy = True\n\
metadata_proxy_shared_secret = 123456" /etc/nova/nova.conf

ln -s /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

systemctl restart openstack-nova-api.service

systemctl enable neutron-server.service \
neutron-linuxbridge-agent.service neutron-dhcp-agent.service \
neutron-metadata-agent.service

systemctl start neutron-server.service \
neutron-linuxbridge-agent.service neutron-dhcp-agent.service \
neutron-metadata-agent.service
#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------
#----------------------------------------------------------------------------------
