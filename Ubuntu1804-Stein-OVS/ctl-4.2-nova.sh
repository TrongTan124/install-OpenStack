#!/bin/bash
#Author Nguyen Trong Tan

source function.sh
source config.sh

# Function create database for Nova
nova_create_db () {
	echocolor "Create database for Nova"
	sleep 3

	cat << EOF | mysql
CREATE DATABASE nova_api;
CREATE DATABASE nova;
CREATE DATABASE nova_cell0;

GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';

GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';

GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY '$NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY '$NOVA_DBPASS';

FLUSH PRIVILEGES;
EOF
}

# Function create infomation for Compute service
nova_create_info () {
	echocolor "Set environment variable for user admin"
	source /root/admin-openrc
	echocolor "Create infomation for Compute service"
	sleep 3

	## Create info for nova user
	echocolor "Create info for nova user"
	sleep 3

	openstack user create --domain default --password $NOVA_PASS nova
	openstack role add --project service --user nova admin
	openstack service create --name nova --description "OpenStack Compute" compute
	openstack endpoint create --region RegionOne compute public http://$CTL_EXT_IP:8774/v2.1
	openstack endpoint create --region RegionOne compute internal http://$CTL_EXT_IP:8774/v2.1
	openstack endpoint create --region RegionOne compute admin http://$CTL_EXT_IP:8774/v2.1

}

# Function install components of Nova
nova_install () {
	echocolor "Install and configure components of Nova"
	sleep 3
	apt install nova-api nova-conductor nova-novncproxy nova-scheduler nova-consoleauth -y
}

# Function config /etc/nova/nova.conf file
nova_config () {
	novafile=/etc/nova/nova.conf
	novafilebak=/etc/nova/nova.conf.bak
	test -f $novafilebak || cp $novafile $novafilebak

	ops_del $novafile api_database connection
	ops_add $novafile api_database connection mysql+pymysql://nova:$NOVA_DBPASS@$CTL_EXT_IP/nova_api

	ops_add $novafile database connection mysql+pymysql://nova:$NOVA_DBPASS@$CTL_EXT_IP/nova

	ops_add $novafile DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$CTL_EXT_IP

	ops_add $novafile api auth_strategy keystone

#	ops_add $novafile keystone_authtoken auth_uri http://$CTL_EXT_IP:5000
	ops_add $novafile keystone_authtoken auth_url http://$CTL_EXT_IP:5000/v3
	ops_add $novafile keystone_authtoken memcached_servers $CTL_EXT_IP:11211
	ops_add $novafile keystone_authtoken auth_type password
	ops_add $novafile keystone_authtoken project_domain_name default
	ops_add $novafile keystone_authtoken user_domain_name default
	ops_add $novafile keystone_authtoken project_name service
	ops_add $novafile keystone_authtoken username nova
	ops_add $novafile keystone_authtoken password $NOVA_PASS

	ops_add $novafile DEFAULT my_ip $CTL_MGNT_IP
	ops_add $novafile DEFAULT use_neutron True
	ops_add $novafile DEFAULT firewall_driver nova.virt.firewall.NoopFirewallDriver

	ops_add $novafile vnc enabled true
	ops_add $novafile vnc server_listen \$my_ip
	ops_add $novafile vnc server_proxyclient_address \$my_ip

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
	
	ops_add $novafile scheduler discover_hosts_in_cells_interval 300
}

# Function populate the nova-api database
nova_populate_nova-api_db () {
echocolor "Populate the nova-api database"
sleep 3
su -s /bin/sh -c "nova-manage api_db sync" nova
}

# Function register the cell0 database
nova_register_cell0 () {
	echocolor "Register the cell0 database"
	sleep 3
	su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
}

# Function create the cell1 cell
nova_create_cell1 () {
	echocolor "Create the cell1 cell"
	sleep 3
	su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
}

# Function populate the nova database
nova_populate_nova_db () {
	echocolor "Populate the nova database"
	sleep 3
	su -s /bin/sh -c "nova-manage db sync" nova
}

# Function verify nova cell0 and cell1 are registered correctly
nova_verify_cell () {
	echocolor "Verify nova cell0 and cell1 are registered correctly"
	sleep 3
	nova-manage cell_v2 list_cells
}

# Function restart installation
nova_restart () {
	echocolor "Finalize installation"
	sleep 3

	service nova-api restart
	service nova-scheduler restart
	service nova-conductor restart
	service nova-novncproxy restart
	service nova-consoleauth restart
}

#######################
###Execute functions###
#######################

# Create database for Nova
nova_create_db

# Create infomation for Compute service
nova_create_info

# Install components of Nova
nova_install

# Config /etc/nova/nova.conf file
nova_config

# Populate the nova-api database
nova_populate_nova-api_db

# Register the cell0 database
nova_register_cell0
	
# Create the cell1 cell
nova_create_cell1

# Populate the nova database
nova_populate_nova_db

# Verify nova cell0 and cell1 are registered correctly
nova_verify_cell

# Restart installation
nova_restart