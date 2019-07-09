#!/bin/bash
#Author Nguyen Trong Tan

source function.sh
source config.sh

# Function update and upgrade for CONTROLLER
update_upgrade () {
	echocolor "Update and Update controller"
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

	sed -i 's/pool ntp.ubuntu.com        iburst maxsources 4/ \
pool 2.debian.pool.ntp.org offline iburst/g' $ntpfile

	sed -i 's/pool 0.ubuntu.pool.ntp.org iburst maxsources 1/ \
server 0.asia.pool.ntp.org iburst/g' $ntpfile

	sed -i 's/pool 1.ubuntu.pool.ntp.org iburst maxsources 1/ \
server 1.asia.pool.ntp.org iburst/g' $ntpfile

	sed -i 's/pool 2.ubuntu.pool.ntp.org iburst maxsources 2//g' $ntpfile

	echo "allow $CIDR_MGNT" >> $ntpfile

	timedatectl set-timezone Asia/Ho_Chi_Minh

	service chrony restart
}

# Function install OpenStack packages (python-openstackclient)
install_ops_packages () {
	echocolor "Install OpenStack client"
	sleep 3
	apt install software-properties-common -y
	add-apt-repository cloud-archive:stein -y
	apt update -y && apt dist-upgrade -y

	apt install python-openstackclient -y
}

# Function install mysql
install_sql () {
	echocolor "Install SQL database - Mariadb"
	sleep 3

	apt install mariadb-server python-pymysql  -y

	sqlfile=/etc/mysql/mariadb.conf.d/99-openstack.cnf
	touch $sqlfile
	cat << EOF >$sqlfile
[client]
default-character-set = utf8
[mysqld]
bind-address = $CTL_EXT_IP
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
[mysql]
default-character-set = utf8
EOF

service mysql restart
}

# Function install message queue
install_mq () {
	echocolor "Install Message queue (rabbitmq)"
	sleep 3

	apt install rabbitmq-server -y
	rabbitmqctl add_user openstack $RABBIT_PASS
	rabbitmqctl set_permissions openstack ".*" ".*" ".*"
}

# Function install Memcached
install_memcached () {
	echocolor "Install Memcached"
	sleep 3

	apt install memcached python-memcache -y
	memcachefile=/etc/memcached.conf
	sed -i 's|-l 127.0.0.1|'"-l $CTL_EXT_IP"'|g' $memcachefile

	service memcached restart
} 

#######################
###Execute functions###
#######################

# Update and upgrade for controller
update_upgrade

# Install crudini
install_crudini

# Install and config NTP
install_ntp

# OpenStack packages (python-openstackclient)
install_ops_packages

# Install SQL database (Mariadb)
install_sql

# Install Message queue (rabbitmq)
install_mq

# Install Memcached
install_memcached
