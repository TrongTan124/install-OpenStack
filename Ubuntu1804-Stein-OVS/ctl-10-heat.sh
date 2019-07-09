#!/bin/bash
#Author Nguyen Trong Tan

source function.sh
source config.sh

# Function create database for heat
heat_create_db () {
	echocolor "Create database for heat"
	sleep 3

	cat << EOF | mysql
CREATE DATABASE heat;

GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'localhost' IDENTIFIED BY '$HEAT_DBPASS';
GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'%' IDENTIFIED BY '$HEAT_DBPASS';

FLUSH PRIVILEGES;
EOF
}

# Function create infomation for orchestration service
heat_create_info () {
	echocolor "Set environment variable for user admin"
	source /root/admin-openrc
	echocolor "Create infomation for orchestration service"
	sleep 3

	## Create info for heat user
	echocolor "Create info for heat user"
	sleep 3

	openstack user create --domain default --password $HEAT_PASS heat
	openstack role add --project service --user heat admin
	openstack service create --name heat --description "Orchestration" orchestration
	openstack service create --name heat-cfn --description "Orchestration"  cloudformation
	
	openstack endpoint create --region RegionOne orchestration public http://$CTL_EXT_IP:8004/v1/%\(tenant_id\)s
	openstack endpoint create --region RegionOne orchestration internal http://$CTL_EXT_IP:8004/v1/%\(tenant_id\)s
	openstack endpoint create --region RegionOne orchestration admin http://$CTL_EXT_IP:8004/v1/%\(tenant_id\)s

	openstack endpoint create --region RegionOne cloudformation public http://$CTL_EXT_IP:8000/v1
	openstack endpoint create --region RegionOne cloudformation internal http://$CTL_EXT_IP:8000/v1
	openstack endpoint create --region RegionOne cloudformation admin http://$CTL_EXT_IP:8000/v1
	
	openstack domain create --description "Stack projects and users" heat
	openstack user create --domain heat --password $HEAT_PASS heat_domain_admin
	openstack role add --domain heat --user-domain heat --user heat_domain_admin admin
	openstack role create heat_stack_owner
	openstack role add --project demo --user demo heat_stack_owner
	
	openstack role create heat_stack_user
}

# Function install components of heat
heat_install () {
	echocolor "Install and configure components of heat"
	sleep 3
	apt install heat-api heat-api-cfn heat-engine -y
}

# Function config /etc/heat/heat.conf file
heat_config () {
	heatfile=/etc/heat/heat.conf
	heatfilebak=/etc/heat/heat.conf.bak
	test -f $heatfilebak || cp $heatfile $heatfilebak

	ops_del $heatfile database connection
	ops_add $heatfile database connection mysql+pymysql://heat:$HEAT_DBPASS@$CTL_EXT_IP/heat

	ops_add $heatfile DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$CTL_EXT_IP

	ops_add $heatfile keystone_authtoken auth_uri http://$CTL_EXT_IP:5000
	ops_add $heatfile keystone_authtoken auth_url http://$CTL_EXT_IP:5000/v3
	ops_add $heatfile keystone_authtoken memcached_servers $CTL_EXT_IP:11211
	ops_add $heatfile keystone_authtoken auth_type password
	ops_add $heatfile keystone_authtoken project_domain_name default
	ops_add $heatfile keystone_authtoken user_domain_name default
	ops_add $heatfile keystone_authtoken project_name service
	ops_add $heatfile keystone_authtoken username heat
	ops_add $heatfile keystone_authtoken password $HEAT_PASS
		
	ops_add $heatfile trustee auth_type password
	ops_add $heatfile trustee auth_url http://$CTL_EXT_IP:5000
	ops_add $heatfile trustee username heat
	ops_add $heatfile trustee password $HEAT_PASS
	ops_add $heatfile trustee user_domain_name default

	ops_add $heatfile clients_keystone auth_uri http://$CTL_EXT_IP:5000

	ops_add $heatfile DEFAULT heat_metadata_server_url http://$CTL_EXT_IP:8000
	ops_add $heatfile DEFAULT heat_waitcondition_server_url http://$CTL_EXT_IP:8000/v1/waitcondition
	ops_add $heatfile DEFAULT stack_domain_admin heat_domain_admin
	ops_add $heatfile DEFAULT stack_domain_admin_password $HEAT_DOMAIN_PASS
	ops_add $heatfile DEFAULT stack_user_domain_name heat
	
}

# Function populate the heat-api database
heat_populate_heat_db () {
echocolor "Populate the heat database"
sleep 3
su -s /bin/sh -c "heat-manage db_sync" heat
}

# Function restart installation
heat_restart () {
	echocolor "Finalize installation"
	sleep 3

	service heat-api restart
	service heat-api-cfn restart
	service heat-engine restart

}

confirm_heat () {
	echocolor "Confirm install complete heat"
	sleep 3
	openstack orchestration service list
}

#######################
###Execute functions###
#######################

# Create database for heat
heat_create_db

# Create infomation for Compute service
heat_create_info

# Install components of heat
heat_install

# Config /etc/heat/heat.conf file
heat_config

# Populate the heat-api database
heat_populate_heat_db

# Restart installation
heat_restart

# Confirm heat
confirm_heat