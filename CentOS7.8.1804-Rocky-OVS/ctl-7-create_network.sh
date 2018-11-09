#!/bin/bash
#Author Nguyen Trong Tan

source function.sh
source config.sh

echocolor "Create provider network, subnet and flavor"
source /root/admin-openrc

openstack network create provider --project service --share \
	--description "Provider network" --external \
	--provider-network-type flat \
	--provider-physical-network provider

openstack subnet create sub-provider --subnet-range $CIDR_EXT \
	--dhcp --dns-nameserver 8.8.8.8 \
	--allocation-pool start=$DHCP_START,end=$DHCP_END \
	--gateway $GATEWAY_EXT_IP \
	--description "Subnet for provider network" \
	--network provider

openstack flavor create timy --ram 128 --disk 1 --vcpus 1
