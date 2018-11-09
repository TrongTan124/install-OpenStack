#!/bin/bash
#Author Nguyen Trong Tan

source function.sh
source config.sh

# Function install the components Neutron
neutron_install () {
	echocolor "Install the components Neutron"
	sleep 3

	yum install openstack-neutron-openvswitch ebtables ipset -y
	
	systemctl restart openvswitch
}

# Function configure the common component
neutron_config_server_component () {
	echocolor "Configure the common component"
	sleep 3

	neutronfile=/etc/neutron/neutron.conf
	neutronfilebak=/etc/neutron/neutron.conf.bak
	cp $neutronfile $neutronfilebak
	egrep -v "^$|^#" $neutronfilebak > $neutronfile

	ops_add $neutronfile DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$HOST_CTL

	ops_add $neutronfile DEFAULT auth_strategy keystone
	ops_add $neutronfile keystone_authtoken www_authenticate_uri http://$HOST_CTL:5000
	ops_add $neutronfile keystone_authtoken auth_url http://$HOST_CTL:5000
	ops_add $neutronfile keystone_authtoken memcached_servers $HOST_CTL:11211
	ops_add $neutronfile keystone_authtoken auth_type password
	ops_add $neutronfile keystone_authtoken project_domain_name default
	ops_add $neutronfile keystone_authtoken user_domain_name default
	ops_add $neutronfile keystone_authtoken project_name service
	ops_add $neutronfile keystone_authtoken username neutron
	ops_add $neutronfile keystone_authtoken password $NEUTRON_PASS

	ops_add $neutronfile oslo_concurrency lock_path /var/lib/neutron/tmp
}

# Function configure the Open vSwitch agent
neutron_config_ovs () {
	echocolor "Configure the Open vSwitch agent"
	sleep 3
	ovsfile=/etc/neutron/plugins/ml2/openvswitch_agent.ini
	ovsfilebak=/etc/neutron/plugins/ml2/openvswitch_agent.ini.bak
	cp $ovsfile $ovsfilebak
	egrep -v "^$|^#" $ovsfilebak > $ovsfile
	
	ops_add $ovsfile agent tunnel_types vxlan
	ops_add $ovsfile agent l2_population True

	ops_add $ovsfile ovs bridge_mappings provider:br-provider
	ops_add $ovsfile ovs local_ip $COM1_MGNT_IP
	
	ops_add $ovsfile securitygroup firewall_driver openvswitch
}

# Function configure things relation
neutron_config_relation () {
	ovs-vsctl add-br br-provider
	ovs-vsctl add-port br-provider $COM1_EXT_IF
	ip a flush  $COM1_EXT_IF
	ip a add $COM1_EXT_IP/$PREFIX_EXT dev br-provider
	ip link set br-provider up
	ip r add default via $GATEWAY_EXT_IP
	echo "nameserver 8.8.8.8" > /etc/resolv.conf
	
	cat << EOF > /etc/sysconfig/network-scripts/ifcfg-$COM1_EXT_IF
# DEVICE=$COM1_EXT_IF
# BOOTPROTO=none
# ONBOOT=yes
# IPADDR=$COM1_EXT_IP
# NETMASK=$COM1_EXT_NETMASK
# GATEWAY=$GATEWAY_EXT_IP
# DNS1=8.8.8.8
# DNS2=8.8.4.4


DEVICE=$COM1_EXT_IF
ONBOOT=yes
DEVICETYPE=ovs
TYPE=OVSPort
OVS_BRIDGE=br-provider
BOOTPROTO=none
EOF
	
	touch /etc/sysconfig/network-scripts/ifcfg-br-provider
	cat << EOF > /etc/sysconfig/network-scripts/ifcfg-br-provider
DEVICE=br-provider
ONBOOT=yes
DEVICETYPE=ovs
TYPE=OVSBridge
BOOTPROTO=none
EOF

	touch /sbin/ifup-local
	chmod +x /sbin/ifup-local
	cat << EOF > /sbin/ifup-local
if [[ "\$1" == "$COM1_EXT_IF" ]]
then
	ip a add $COM1_EXT_IP/$PREFIX_EXT dev br-provider
	ip r add default via $GATEWAY_EXT_IP
	echo "nameserver 8.8.8.8" > /etc/resolv.conf
fi
EOF
}

# Function configure the Compute service to use the Networking service
neutron_config_compute_use_network () {
	echocolor "Configure the Compute service to use the Networking service"
	sleep 3
	novafile=/etc/nova/nova.conf

	ops_add $novafile neutron url http://$HOST_CTL:9696
	ops_add $novafile neutron auth_url http://$HOST_CTL:5000
	ops_add $novafile neutron auth_type password
	ops_add $novafile neutron project_domain_name default
	ops_add $novafile neutron user_domain_name default
	ops_add $novafile neutron region_name RegionOne
	ops_add $novafile neutron project_name service
	ops_add $novafile neutron username neutron
	ops_add $novafile neutron password $NEUTRON_PASS
}

# Function restart installation
neutron_restart () {
	echocolor "Finalize installation"
	sleep 3
	systemctl restart openstack-nova-compute.service
	
	systemctl enable neutron-openvswitch-agent.service
	systemctl start neutron-openvswitch-agent.service
}

#######################
###Execute functions###
#######################

# Install the components Neutron
neutron_install

# Configure the common component
neutron_config_server_component

# Configure the Open vSwitch agent
neutron_config_ovs

# Configure things relation
neutron_config_relation
	
# Configure the Compute service to use the Networking service
neutron_config_compute_use_network
	
# Restart installation
neutron_restart