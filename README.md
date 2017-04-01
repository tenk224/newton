on controller and compute nodes:
run init_.sh at the same time
-> reboot
run controller.sh on controller node first and then compute.sh on compute node with the following command
./controller <ip add of controller> <interface of that ip add>
./compute <ip add of compute> <interface of that ip add>
you need to manually setup MySQL secure setup when prompted
run verify.sh to verify all services are installed correctly and running

Based on this guide https://docs.openstack.org/newton/install-guide-rdo/
