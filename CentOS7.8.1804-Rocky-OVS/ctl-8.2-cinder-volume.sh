#!/bin/bash
#Author Nguyen Trong Tan

source function.sh
source config.sh

# Function install lvm2
cinder_install_lvm () {
	echocolor "Install lvm2"
	sleep 3
	yum install lvm2 device-mapper-persistent-data -y
	
	systemctl enable lvm2-lvmetad.service
	systemctl start lvm2-lvmetad.service
}

# Function config lvm
cinder_config_lvm () {
	echocolor "Config lvm"
	
	pvcreate /dev/sda

	vgcreate cinder-volumes /dev/sda
		
	string="filter = [ \"a/sda/\", \"r/.*/\"]"

	lvmfile=/etc/lvm/lvm.conf
	sed -i 's|# Accept every block device:|'"$string"'|g' $lvmfile
}

# Function install cinder-volume
cinder_install_cinder-volume () {
	echocolor "Install cinder-volume"
	sleep 3
	yum install openstack-cinder targetcli python-keystone -y
}

# Function config /etc/cinder/cinder.conf
cinder_config () {
	echocolor "Config /etc/cinder/cinder.conf"
	
	cinderapifile=/etc/cinder/cinder.conf
	cinderapifilebak=/etc/cinder/cinder.conf.bak
	cp $cinderapifile $cinderapifilebak
	egrep -v "^#|^$"  $cinderapifilebak > $cinderapifile

	ops_add $cinderapifile lvm volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
	ops_add $cinderapifile lvm volume_group cinder-volumes
	ops_add $cinderapifile lvm iscsi_protocol iscsi
	ops_add $cinderapifile lvm iscsi_helper lioadm
	ops_add $cinderapifile lvm volume_backend_name lvm
	
	ops_add $cinderapifile DEFAULT enabled_backends lvm
	ops_add $cinderapifile DEFAULT glance_api_servers http://$HOST_CTL:9292
}

# Function cinder restart
cinder_restart () {
	echocolor "Cinder restart"
	
	systemctl enable openstack-cinder-volume.service target.service
	systemctl restart openstack-cinder-volume.service target.service
}

# Create volume type
cinder_create_volume_type () {
	echocolor "Cinder create volume type"
	source /root/admin-openrc
	
	openstack volume type create lvm
	openstack volume type set lvm --property volume_backend_name=lvm
}

#######################
###Execute functions###
#######################

# Function install lvm2
cinder_install_lvm

# Function config lvm
cinder_config_lvm

# Function install cinder-volume
cinder_install_cinder-volume

# Function config /etc/cinder/cinder.conf
cinder_config

# Function cinder restart
cinder_restart

# Create volume type
cinder_create_volume_type