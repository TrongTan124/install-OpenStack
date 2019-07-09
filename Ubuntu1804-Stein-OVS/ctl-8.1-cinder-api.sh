#!/bin/bash
#Author Nguyen Trong Tan
# 1. Tạo volume trên web-virt
# 2. SSH vào host vật lý
# 3. Chạy lệnh sudo virt-manager
# 4. Mở VM cần mount Volume
# 5. Add device cho VM, chọn storage
# 6. Chọn type là virtio disk, và format là qcow2
# 7. Apply

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
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'$CTL_EXT_IP' IDENTIFIED BY '$CINDER_DBPASS';
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

	openstack endpoint create --region RegionOne volumev2 public http://$CTL_EXT_IP:8776/v2/%\(project_id\)s
	openstack endpoint create --region RegionOne volumev2 internal http://$CTL_EXT_IP:8776/v2/%\(project_id\)s
	openstack endpoint create --region RegionOne volumev2 admin http://$CTL_EXT_IP:8776/v2/%\(project_id\)s
	openstack endpoint create --region RegionOne volumev3 public http://$CTL_EXT_IP:8776/v3/%\(project_id\)s
	openstack endpoint create --region RegionOne volumev3 internal http://$CTL_EXT_IP:8776/v3/%\(project_id\)s
	openstack endpoint create --region RegionOne volumev3 admin http://$CTL_EXT_IP:8776/v3/%\(project_id\)s
}

# Function install components of Cinder
cinder_install () {
	echocolor "Install and configure components of Cinder"
	sleep 3

	apt install cinder-api cinder-scheduler -y
}

# Function config /etc/cinder/cinder.conf file
cinder_config () {
	cinderapifile=/etc/cinder/cinder.conf
	cinderapifilebak=/etc/cinder/cinder.conf.bak
	test -f $cinderapifilebak || cp $cinderapifile $cinderapifilebak
	
	ops_add $cinderapifile database connection mysql+pymysql://cinder:$CINDER_DBPASS@$CTL_EXT_IP/cinder

	ops_add $cinderapifile DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$CTL_EXT_IP
	ops_add $cinderapifile DEFAULT auth_strategy keystone
	ops_add $cinderapifile DEFAULT my_ip $CTL_MGNT_IP
	
	ops_add $cinderapifile  keystone_authtoken www_authenticate_uri http://$CTL_EXT_IP:5000
	ops_add $cinderapifile  keystone_authtoken auth_url http://$CTL_EXT_IP:5000
	ops_add $cinderapifile  keystone_authtoken memcached_servers $CTL_EXT_IP:11211
	ops_add $cinderapifile  keystone_authtoken auth_type password
	ops_add $cinderapifile  keystone_authtoken project_domain_name default
	ops_add $cinderapifile  keystone_authtoken user_domain_name default
	ops_add $cinderapifile  keystone_authtoken project_name service
	ops_add $cinderapifile  keystone_authtoken username cinder
	ops_add $cinderapifile  keystone_authtoken password $CINDER_PASS
		
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
	ops_add /etc/nova/nova.conf cinder os_region_name RegionOne
}

# Function restart the Block Storage services
cinder_restart () {
	echocolor "Restart the Block Storage services"
	sleep 3

	service nova-api restart	
	service cinder-scheduler restart
	service apache2 restart
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