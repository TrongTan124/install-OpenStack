#!/bin/bash
#Author Nguyen Trong Tan

source function.sh
source config.sh

# Function update and upgrade for COMPUTE
update_upgrade () {
	echocolor "Update and Upgrade COMPUTE"
	sleep 3
	apt update -y && apt upgrade -y
}

# Function install crudini
install_crudini () {
	echocolor "Install crudini"
	sleep 3
	apt install -y crudini
}

# Function install and config NTP
install_ntp () {
	echocolor "Install NTP"
	sleep 3

	apt install chrony -y
	ntpfile=/etc/chrony/chrony.conf

	sed -i 's|'"pool 2.debian.pool.ntp.org offline iburst"'| \
	'"server $HOST_CTL iburst"'|g' $ntpfile

	service chrony restart
}

# Function install OpenStack packages (python-openstackclient)
install_ops_packages () {
	echocolor "Install OpenStack client"
	sleep 3
	apt install software-properties-common -y
	add-apt-repository cloud-archive:rocky -y
	apt update -y && apt dist-upgrade -y

	apt install python-openstackclient -y
}

#######################
###Execute functions###
#######################

# Update and upgrade for COMPUTE
update_upgrade

# Install crudini
install_crudini

# Install and config NTP
install_ntp

# OpenStack packages (python-openstackclient)
install_ops_packages
