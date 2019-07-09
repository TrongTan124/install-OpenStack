#!/bin/bash
#Author Nguyen Trong Tan

source function.sh
source config.sh

# Function install nova-compute
nova_install () {
	echocolor "Install nova-compute"
	sleep 3
	apt install nova-compute -y
}

# Function edit /etc/nova/nova.conf file
nova_config () {
	echocolor "Edit /etc/nova/nova.conf file"
	sleep 3
	novafile=/etc/nova/nova.conf
	novafilebak=/etc/nova/nova.conf.bak
	test -f $novafilebak || cp $novafile $novafilebak

	ops_add $novafile DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$CTL_EXT_IP

	ops_add $novafile api auth_strategy keystone

	ops_add $novafile keystone_authtoken auth_url http://$CTL_EXT_IP:5000
	ops_add $novafile keystone_authtoken memcached_servers $CTL_EXT_IP:11211
	ops_add $novafile keystone_authtoken auth_type password
	ops_add $novafile keystone_authtoken project_domain_name default
	ops_add $novafile keystone_authtoken user_domain_name default
	ops_add $novafile keystone_authtoken project_name service
	ops_add $novafile keystone_authtoken username nova
	ops_add $novafile keystone_authtoken password $NOVA_PASS

	ops_add $novafile DEFAULT my_ip $COM2_MGNT_IP

	ops_add $novafile DEFAULT use_neutron True

	ops_add $novafile DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

	ops_add $novafile vnc enabled True
	ops_add $novafile vnc server_listen 0.0.0.0
	ops_add $novafile vnc server_proxyclient_address \$my_ip
	ops_add $novafile vnc novncproxy_base_url http://$CTL_EXT_IP:6080/vnc_auto.html

	ops_add $novafile glance api_servers http://$CTL_EXT_IP:9292

	ops_add $novafile oslo_concurrency lock_path /var/lib/nova/tmp
		
	ops_del $novafile DEFAULT log_dir

	ops_del $novafile placement os_region_name
	ops_add $novafile placement os_region_name RegionOne
	ops_add $novafile placement project_domain_name Default
	ops_add $novafile placement project_name service
	ops_add $novafile placement auth_type password
	ops_add $novafile placement user_domain_name Default
	ops_add $novafile placement auth_url http://$CTL_EXT_IP:5000/v3
	ops_add $novafile placement username placement
	ops_add $novafile placement password $PLACEMENT_PASS
	
	novacomputefile=/etc/nova/nova-compute.conf
	novacomputefilebak=/etc/nova/nova-compute.conf.bak
	test -f $novacomputefilebak || cp $novacomputefile $novacomputefilebak

	ops_add $novacomputefile libvirt virt_type qemu
}

# Function finalize installation
nova_restart () {
	echocolor "Finalize installation"
	sleep 3
	service nova-compute restart
}

#######################
###Execute functions###
#######################

# Install nova-compute
nova_install

# Edit /etc/nova/nova.conf file
nova_config

# Finalize installation
nova_restart