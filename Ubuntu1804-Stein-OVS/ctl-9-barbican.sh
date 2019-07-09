#!/bin/bash
#Author Nguyen Trong Tan

source function.sh
source config.sh

# Function create database for barbican
barbican_create_db () {
	echocolor "Create database for barbican"
	sleep 3

	cat << EOF | mysql
CREATE DATABASE barbican;

GRANT ALL PRIVILEGES ON barbican.* TO 'barbican'@'localhost' IDENTIFIED BY '$BARBICAN_DBPASS';
GRANT ALL PRIVILEGES ON barbican.* TO 'barbican'@'%' IDENTIFIED BY '$BARBICAN_DBPASS';

FLUSH PRIVILEGES;
EOF
}

# Function create infomation for orchestration service
barbican_create_info () {
	echocolor "Set environment variable for user admin"
	source /root/admin-openrc
	echocolor "Create infomation for orchestration service"
	sleep 3

	## Create info for barbican user
	echocolor "Create info for barbican user"
	sleep 3

	openstack user create --domain default --password $BARBICAN_PASS barbican
	openstack role add --project service --user barbican admin
	openstack role create creator
	openstack role add --project service --user barbican creator
	openstack service create --name barbican --description "Key Manager" key-manager
	
	openstack endpoint create --region RegionOne key-manager public http://$CTL_EXT_IP:9311
	openstack endpoint create --region RegionOne key-manager internal http://$CTL_EXT_IP:9311
	openstack endpoint create --region RegionOne key-manager admin http://$CTL_EXT_IP:9311

}

# Function install components of barbican
barbican_install () {
	echocolor "Install and configure components of barbican"
	sleep 3
	apt install barbican-api barbican-keystone-listener barbican-worker python-barbicanclient -y
}

# Function config /etc/barbican/barbican.conf file
barbican_config () {
	barbicanfile=/etc/barbican/barbican.conf
	barbicanfilebak=/etc/barbican/barbican.conf.bak
	test -f $barbicanfilebak || cp $barbicanfile $barbicanfilebak

	ops_add $barbicanfile DEFAULT sql_connection mysql+pymysql://barbican:$BARBICAN_DBPASS@$CTL_EXT_IP/barbican

	ops_add $barbicanfile DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$CTL_EXT_IP
	ops_add $barbicanfile DEFAULT host_href http://$CTL_EXT_IP:9311

	ops_add $barbicanfile keystone_authtoken www_authenticate_uri http://$CTL_EXT_IP:5000
	ops_add $barbicanfile keystone_authtoken auth_url http://$CTL_EXT_IP:5000
	ops_add $barbicanfile keystone_authtoken memcached_servers $CTL_EXT_IP:11211
	ops_add $barbicanfile keystone_authtoken auth_type password
	ops_add $barbicanfile keystone_authtoken project_domain_name default
	ops_add $barbicanfile keystone_authtoken user_domain_name default
	ops_add $barbicanfile keystone_authtoken project_name service
	ops_add $barbicanfile keystone_authtoken username barbican
	ops_add $barbicanfile keystone_authtoken password $BARBICAN_PASS
	
	ops_add /etc/nova/nova.conf barbican barbican_endpoint http://$CTL_EXT_IP:9311/v1
	ops_add /etc/nova/nova.conf barbican barbican_api_version v1
	ops_add /etc/nova/nova.conf key_manager backend barbican
}

# Function populate the barbican database
barbican_populate_barbican_db () {
echocolor "Populate the barbican database"
sleep 3
su -s /bin/sh -c "barbican-manage db upgrade" barbican
}

# Function restart installation
barbican_restart () {
	echocolor "Finalize installation"
	sleep 3

	service barbican-keystone-listener restart
	service barbican-worker restart
	service apache2 restart

}

#######################
###Execute functions###
#######################

# Create database for barbican
barbican_create_db

# Create infomation for Compute service
barbican_create_info

# Install components of barbican
barbican_install

# Config /etc/barbican/barbican.conf file
barbican_config

# Populate the barbican-api database
barbican_populate_barbican_db

# Restart installation
barbican_restart