#!/bin/bash
#Author Nguyen Trong Tan

source function.sh
source config.sh

# Function create database for Placement
placement_create_db () {
	echocolor "Create database for Placement"
	sleep 3

	cat << EOF | mysql
CREATE DATABASE placement;

GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY '$PLACEMENT_DBPASS';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY '$PLACEMENT_DBPASS';

FLUSH PRIVILEGES;
EOF
}

# Function create infomation for Placement service
placement_create_info () {
	echocolor "Set environment variable for user admin"
	source /root/admin-openrc
	echocolor "Create infomation for Placement service"
	sleep 3

	## Create info for placement user
	echocolor "Create info for placement user"
	sleep 3

	openstack user create --domain default --password $PLACEMENT_PASS placement
	openstack role add --project service --user placement admin
	openstack service create --name placement --description "Placement API" placement
	openstack endpoint create --region RegionOne placement public http://$CTL_EXT_IP:8778
	openstack endpoint create --region RegionOne placement internal http://$CTL_EXT_IP:8778
	openstack endpoint create --region RegionOne placement admin http://$CTL_EXT_IP:8778

}

# Function install components of Placement
placement_install () {
	echocolor "Install and configure components of Placement"
	sleep 3
	apt install placement-api -y
}

# Function config /etc/placement/placement.conf file
placement_config () {
	placementfile=/etc/placement/placement.conf
	placementfilebak=/etc/placement/placement.conf.bak
	test -f $placementfilebak || cp $placementfile $placementfilebak

	ops_add $placementfile placement_database connection mysql+pymysql://placement:$PLACEMENT_DBPASS@$CTL_EXT_IP/placement

	ops_add $placementfile api auth_strategy keystone

	ops_add $placementfile keystone_authtoken auth_url http://$CTL_EXT_IP:5000/v3
	ops_add $placementfile keystone_authtoken memcached_servers $CTL_EXT_IP:11211
	ops_add $placementfile keystone_authtoken auth_type password
	ops_add $placementfile keystone_authtoken project_domain_name default
	ops_add $placementfile keystone_authtoken user_domain_name default
	ops_add $placementfile keystone_authtoken project_name service
	ops_add $placementfile keystone_authtoken username placement
	ops_add $placementfile keystone_authtoken password $PLACEMENT_PASS

}

# Function populate the placement-api database
placement_populate_placement_db () {
echocolor "Populate the placement-api database"
sleep 3
su -s /bin/sh -c "placement-manage db sync" placement
}

# Function restart installation
placement_restart () {
	echocolor "Finalize installation"
	sleep 3

	service apache2 restart

}

#######################
###Execute functions###
#######################

# Create database for Nova
placement_create_db

# Create infomation for Compute service
placement_create_info

# Install components of Nova
placement_install

# Config /etc/placement/placement.conf file
placement_config

# Populate the placement-api database
placement_populate_placement_db

# Restart installation
placement_restart