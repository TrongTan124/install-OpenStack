#!/bin/bash
#Author Nguyen Trong Tan

source function.sh
source config.sh

# Function create database for magnum
magnum_create_db () {
	echocolor "Create database for magnum"
	sleep 3

	cat << EOF | mysql
CREATE DATABASE magnum;

GRANT ALL PRIVILEGES ON magnum.* TO 'magnum'@'localhost' IDENTIFIED BY '$MAGNUM_DBPASS';
GRANT ALL PRIVILEGES ON magnum.* TO 'magnum'@'%' IDENTIFIED BY '$MAGNUM_DBPASS';

FLUSH PRIVILEGES;
EOF
}

# Function create infomation for Container service
magnum_create_info () {
	echocolor "Set environment variable for user admin"
	source /root/admin-openrc
	echocolor "Create infomation for Container service"
	sleep 3

	## Create info for magnum user
	echocolor "Create info for magnum user"
	sleep 3

	openstack user create --domain default --password $MAGNUM_PASS magnum
	openstack role add --project service --user magnum admin
	openstack service create --name magnum --description "OpenStack Container Infrastructure Management Service" container-infra
	
	openstack endpoint create --region RegionOne container-infra public http://$CTL_EXT_IP:9511/v1
	openstack endpoint create --region RegionOne container-infra internal http://$CTL_EXT_IP:9511/v1
	openstack endpoint create --region RegionOne container-infra admin http://$CTL_EXT_IP:9511/v1

	
	openstack domain create --description "Owns users and projects created by magnum" magnum
	openstack user create --domain magnum --password $MAGNUM_PASS magnum_domain_admin
	openstack role add --domain magnum --user-domain magnum --user magnum_domain_admin admin

}

# Function install components of magnum
magnum_install () {
	echocolor "Install and configure components of magnum"
	sleep 3
	DEBIAN_FRONTEND=noninteractive apt install magnum-api magnum-conductor python-magnumclient -y
}

# Function config /etc/magnum/magnum.conf file
magnum_config () {
	magnumfile=/etc/magnum/magnum.conf
	magnumfilebak=/etc/magnum/magnum.conf.bak
	test -f $magnumfilebak || cp $magnumfile $magnumfilebak

	ops_add $magnumfile DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$CTL_EXT_IP
	ops_add $magnumfile DEFAULT debug true
	
	ops_add $magnumfile api host $CTL_EXT_IP
	ops_add $magnumfile certificates cert_manager_type barbican
	
	ops_add $magnumfile database connection mysql+pymysql://magnum:$MAGNUM_DBPASS@$CTL_EXT_IP/magnum
	
	ops_add $magnumfile barbican_client region_name RegionOne
	ops_add $magnumfile cinder_client region_name RegionOne
	ops_add $magnumfile glance_client region_name RegionOne
	ops_add $magnumfile heat_client region_name RegionOne
	ops_add $magnumfile magnum_client region_name RegionOne
	ops_add $magnumfile neutron_client region_name RegionOne
	ops_add $magnumfile nova_client region_name RegionOne

	ops_del $magnumfile keystone_authtoken www_authenticate_uri
	
	ops_add $magnumfile keystone_authtoken memcached_servers $CTL_EXT_IP:11211
	ops_add $magnumfile keystone_authtoken auth_version v3
	ops_add $magnumfile keystone_authtoken auth_uri http://$CTL_EXT_IP:5000/v3
	ops_add $magnumfile keystone_authtoken project_domain_name default
	ops_add $magnumfile keystone_authtoken project_name service
	ops_add $magnumfile keystone_authtoken user_domain_name default
	ops_add $magnumfile keystone_authtoken password $MAGNUM_PASS
	ops_add $magnumfile keystone_authtoken username magnum
	ops_add $magnumfile keystone_authtoken auth_url http://$CTL_EXT_IP:5000
	ops_add $magnumfile keystone_authtoken auth_type password
	ops_add $magnumfile keystone_authtoken region_name RegionOne
	
#	ops_add $magnumfile keystone_authtoken admin_user magnum
#	ops_add $magnumfile keystone_authtoken admin_password $MAGNUM_PASS
#	ops_add $magnumfile keystone_authtoken admin_tenant_name service

	ops_add $magnumfile keystone_auth auth_url http://$CTL_EXT_IP:5000
	ops_add $magnumfile keystone_auth user_domain_name default
	ops_add $magnumfile keystone_auth project_domain_name default
	ops_add $magnumfile keystone_auth project_name service
	ops_add $magnumfile keystone_auth password $MAGNUM_PASS
	ops_add $magnumfile keystone_auth username magnum
	ops_add $magnumfile keystone_auth auth_type password
		
	ops_add $magnumfile trust trustee_domain_name magnum
	ops_add $magnumfile trust trustee_domain_admin_name magnum_domain_admin
	ops_add $magnumfile trust trustee_domain_admin_password $DOMAIN_ADMIN_PASS
	ops_add $magnumfile trust trustee_keystone_interface public
	
	ops_add $magnumfile cinder default_docker_volume_type lvm
	
	ops_add $magnumfile drivers send_cluster_metrics False
	ops_add $magnumfile drivers verify_ca true

	ops_add $magnumfile oslo_messaging_notifications driver messaging
	
	ops_add $magnumfile oslo_concurrency lock_path /var/lock/magnum
	
	ops_add $magnumfile oslo_policy policy_file /etc/magnum/policy.yaml

}

# Function populate the magnum-api database
magnum_populate_magnum_db () {
echocolor "Populate the magnum-api database"
sleep 3
su -s /bin/sh -c "magnum-db-manage upgrade" magnum
}

# Function restart installation
magnum_restart () {
	echocolor "Finalize installation"
	sleep 3

	service magnum-api restart
	service magnum-conductor restart

}

#######################
###Execute functions###
#######################

# Create database for magnum
magnum_create_db

# Create infomation for Compute service
magnum_create_info

# Install components of magnum
magnum_install

# Config /etc/magnum/magnum.conf file
magnum_config

# Populate the magnum-api database
magnum_populate_magnum_db

# Restart installation
magnum_restart