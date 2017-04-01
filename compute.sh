#!/bin/bash

ipadd=$1
ifname=$2

yum install openstack-nova-compute \
openstack-neutron-linuxbridge ebtables ipset -y

#----------------------------------------------------------------------------------
sed -i "/^\[DEFAULT\]$/a enabled_apis = osapi_compute,metadata\n\
transport_url = rabbit://openstack:123456@controller\n\
auth_strategy = keystone\n\
my_ip = $ipadd\n\
use_neutron = True\n\
firewall_driver = nova.virt.firewall.NoopFirewallDriver" /etc/nova/nova.conf

sed -i "/^\[keystone_authtoken\]$/a auth_uri = http://controller:5000\n\
auth_url = http://controller:35357\n\
memcached_servers = controller:11211\n\
auth_type = password\n\
project_domain_name = Default\n\
user_domain_name = Default\n\
project_name = service\n\
username = nova\n\
password = 123456" /etc/nova/nova.conf

sed -i "/^\[vnc\]$/a enabled = True\n\
vncserver_listen = 0.0.0.0\n\
vncserver_proxyclient_address = $my_ip\n\
novncproxy_base_url = http://controller:6080/vnc_auto.html" /etc/nova/nova.conf

sed -i "/^\[glance\]$/a api_servers = http://controller:9292" /etc/nova/nova.conf

sed -i "/^\[oslo_concurrency\]$/a lock_path = /var/lib/nova/tmp" /etc/nova/nova.conf

sed -i "/^\[libvirt\]$/a virt_type = qemu" /etc/nova/nova.conf

systemctl enable libvirtd.service openstack-nova-compute.service
systemctl start libvirtd.service openstack-nova-compute.service
#----------------------------------------------------------------------------------
sed -i "/^\[DEFAULT\]$/a transport_url = rabbit://openstack:123456@controller\n\
auth_strategy = keystone" /etc/neutron/neutron.conf

sed -i "/^\[keystone_authtoken\]$/a auth_uri = http://controller:5000\n\
auth_url = http://controller:35357\n\
memcached_servers = controller:11211\n\
auth_type = password\n\
project_domain_name = Default\n\
user_domain_name = Default\n\
project_name = service\n\
username = neutron\n\
password = 123456" /etc/neutron/neutron.conf

sed -i "/^\[oslo_concurrency\]$/a lock_path = /var/lib/neutron/tmp" /etc/neutron/neutron.conf

sed -i "/^\[linux_bridge\]$/a physical_interface_mappings = provider:$ifname" /etc/neutron/plugins/ml2/linuxbridge_agent.ini

sed -i "/^\[vxlan\]$/a enable_vxlan = False" /etc/neutron/plugins/ml2/linuxbridge_agent.ini

sed -i "/^\[securitygroup\]$/a enable_security_group = False\n\
firewall_driver = neutron.agent.firewall.NoopFirewallDriver" /etc/neutron/plugins/ml2/linuxbridge_agent.ini

sed -i "/^\[neutron\]$/a url = http://controller:9696\n\
auth_url = http://controller:35357\n\
auth_type = password\n\
project_domain_name = Default\n\
user_domain_name = Default\n\
region_name = RegionOne\n\
project_name = service\n\
username = neutron\n\
password = 123456" /etc/nova/nova.conf

systemctl restart openstack-nova-compute.service
systemctl enable neutron-linuxbridge-agent.service
systemctl start neutron-linuxbridge-agent.service
#----------------------------------------------------------------------------------
