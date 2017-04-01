#!/bin/bash

yum install wget -y

wget http://download.cirros-cloud.net/0.3.4/cirros-0.3.4-x86_64-disk.img

openstack image create \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3 \
"cirros" \
--file cirros-0.3.4-x86_64-disk.img \
--disk-format qcow2 --container-format bare \
--public

openstack image list \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3

openstack compute service list \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3

openstack network agent list \
--os-project-domain-name default \
--os-user-domain-name default \
--os-project-name admin \
--os-username admin \
--os-password 123456 \
--os-auth-url http://controller:35357/v3 \
--os-identity-api-version 3

