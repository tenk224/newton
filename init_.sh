#!/bin/bash


sed -i 's/=enforcing/=disabled/g' /etc/sysconfig/selinux
systemctl stop firewalld
systemctl disable firewalld
systemctl stop NetworkManager
systemctl disable NetworkManager

yum install centos-release-openstack-newton -y
yum upgrade -y
yum install python-openstackclient \
openstack-selinux -y

rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-2.el7.elrepo.noarch.rpm
yum --enablerepo=elrepo-kernel install kernel-ml -y

sed -i 's/saved/0/g' /etc/default/grub
sed -i 's/5/0/g' /etc/default/grub

grub2-mkconfig -o /boot/grub2/grub.cfg
