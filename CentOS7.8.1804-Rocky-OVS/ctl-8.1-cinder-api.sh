#!/bin/bash
#Author Nguyen Trong Tan

source function.sh
source config.sh

# Function create database for Cinder
cinder_create_db () {
	echocolor "Create database for Cinder"
	sleep 3

	cat << EOF | mysql
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY '$CINDER_DBPASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY '$CINDER_DBPASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'$CTL_MGNT_IP' IDENTIFIED BY '$CINDER_DBPASS';
EOF
}

# Function create the Cinder service credentials
cinder_create_service () {
	echocolor "Set variable environment for admin user"
	sleep 3
	source /root/admin-openrc

	echocolor "Create the service credentials"
	sleep 3

	openstack user create --domain default --password $CINDER_PASS cinder
	openstack role add --project service --user cinder admin
	openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
	openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3
	openstack endpoint create --region RegionOne volumev2 public http://$HOST_CTL:8776/v2/%\(project_id\)s
	openstack endpoint create --region RegionOne volumev2 internal http://$HOST_CTL:8776/v2/%\(project_id\)s
	openstack endpoint create --region RegionOne volumev2 admin http://$HOST_CTL:8776/v2/%\(project_id\)s
	openstack endpoint create --region RegionOne volumev3 public http://$HOST_CTL:8776/v3/%\(project_id\)s
	openstack endpoint create --region RegionOne volumev3 internal http://$HOST_CTL:8776/v3/%\(project_id\)s
	openstack endpoint create --region RegionOne volumev3 admin http://$HOST_CTL:8776/v3/%\(project_id\)s
}

# Function install components of Cinder
cinder_install () {
	echocolor "Install and configure components of Cinder"
	sleep 3

	yum install cinder-api -y
}

# Function config /etc/cinder/cinder.conf file
cinder_config () {
	cinderapifile=/etc/cinder/cinder.conf
	cinderapifilebak=/etc/cinder/cinder.conf.bak
	cp $cinderapifile $cinderapifilebak
	egrep -v "^#|^$"  $cinderapifilebak > $cinderapifile
	
	ops_del $cinderapifile database connection
	ops_add $cinderapifile database connection mysql+pymysql://cinder:$CINDER_DBPASS@$HOST_CTL/cinder

	ops_add $cinderapifile DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$HOST_CTL
	ops_add $cinderapifile DEFAULT auth_strategy keystone
	
	ops_add $cinderapifile  keystone_authtoken auth_uri http://$HOST_CTL:5000
	ops_add $cinderapifile  keystone_authtoken auth_url http://$HOST_CTL:5000
	ops_add $cinderapifile  keystone_authtoken memcached_servers $HOST_CTL:11211
	ops_add $cinderapifile  keystone_authtoken auth_type password
	ops_add $cinderapifile  keystone_authtoken project_domain_name default
	ops_add $cinderapifile  keystone_authtoken user_domain_name default
	ops_add $cinderapifile  keystone_authtoken project_name service
	ops_add $cinderapifile  keystone_authtoken username cinder
	ops_add $cinderapifile  keystone_authtoken password $CINDER_PASS
	
	ops_add $cinderapifile DEFAULT my_ip $CTL_MGNT_IP
	
	ops_add $cinderapifile oslo_concurrency lock_path /var/lib/cinder/tmp
}

# Function populate the Block Storage database
cinder_populate_db () {
	echocolor "Populate the Block Storage database"
	sleep 3
	su -s /bin/sh -c "cinder-manage db sync" cinder
}

# Function config Compute to use Block Storage
cinder_config_compute_use_block () {
	ops_add /etc/nova/nova.conf oslo_concurrency os_region_name RegionOne
}

# Function restart the Block Storage services
cinder_restart () {
	echocolor "Restart the Block Storage services"
	sleep 3

	systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service	
	systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service
}

#######################
###Execute functions###
#######################

# Function create database for Cinder
cinder_create_db

# Function create the Cinder service credentials
cinder_create_service

# Function install components of Cinder
cinder_install

# Function config /etc/cinder/cinder.conf file
cinder_config

# Function populate the Block Storage database
cinder_populate_db

# Function config Compute to use Block Storage
cinder_config_compute_use_block

# Function restart the Block Storage services
cinder_restart