#!/bin/bash
#Author Nguyen Trong Tan

source function.sh
source config.sh

# Function install lvm2
cinder_install_lvm () {
	echocolor "Install lvm2"
	sleep 3
	apt install lvm2 thin-provisioning-tools -y

}

# Function config lvm
cinder_config_lvm () {
	echocolor "Config lvm"
	
	CHECK_VOLUME=`lsblk |grep $VOLUME_NAME |awk '{ print $1 }'`

	if [[ "$CHECK_VOLUME" == "$VOLUME_NAME" ]]; then
		pvcreate /dev/$VOLUME_NAME

		vgcreate cinder-volumes /dev/$VOLUME_NAME
			
		string="filter = [ \"a/$VOLUME_NAME/\", \"r/.*/\"]"

		lvmfile=/etc/lvm/lvm.conf
		sed -i 's|# Accept every block device:|'"$string"'|g' $lvmfile
	else
		echocolor "Volume do not exit!!!"
		exit
	fi

}

# Function install cinder-volume
cinder_install_cinder-volume () {
	echocolor "Install cinder-volume"
	sleep 3
	apt install cinder-volume -y
}

# Function config /etc/cinder/cinder.conf
cinder_config () {
	echocolor "Config /etc/cinder/cinder.conf"
	
	cinderapifile=/etc/cinder/cinder.conf
	cinderapifilebak=/etc/cinder/cinder.conf.bak
	test -f $cinderapifilebak || cp $cinderapifile $cinderapifilebak

	ops_add $cinderapifile lvm volume_driver cinder.volume.drivers.lvm.LVMVolumeDriver
	ops_add $cinderapifile lvm volume_group cinder-volumes
	ops_add $cinderapifile lvm target_protocol iscsi
	ops_add $cinderapifile lvm target_helper tgtadm
	ops_add $cinderapifile lvm volume_backend_name lvm
	
	ops_add $cinderapifile DEFAULT enabled_backends lvm
	ops_add $cinderapifile DEFAULT glance_api_servers http://$CTL_EXT_IP:9292
}

# Function cinder restart
cinder_restart () {
	echocolor "Cinder restart"
	
	service tgt restart
	service cinder-scheduler restart
	service cinder-volume restart
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

# Create volume type
cinder_create_volume_type

# Function cinder restart
cinder_restart