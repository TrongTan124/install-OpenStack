#!/bin/bash
# Author Nguyen Trong Tan

source function.sh
source config.sh

# Function create database for Neutron
neutron_create_db () {
	echocolor "Create database for Neutron"
	sleep 3

	cat << EOF | mysql
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY '$NEUTRON_DBPASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY '$NEUTRON_DBPASS';
FLUSH PRIVILEGES;
EOF
}

# Function create the neutron service credentials
neutron_create_info () {
	echocolor "Set environment variable for admin user"
	source /root/admin-openrc
	echocolor "Create the neutron service credentials"
	sleep 3

	openstack user create --domain default --password $NEUTRON_PASS neutron
	openstack role add --project service --user neutron admin
	openstack service create --name neutron --description "OpenStack Networking" network
	openstack endpoint create --region RegionOne network public http://$CTL_EXT_IP:9696
	openstack endpoint create --region RegionOne network internal http://$CTL_EXT_IP:9696
	openstack endpoint create --region RegionOne network admin http://$CTL_EXT_IP:9696
}

# Function install the components
neutron_install () {
	echocolor "Install the components"
	sleep 3
	
	apt install neutron-server neutron-plugin-ml2 \
	  neutron-openvswitch-agent neutron-l3-agent neutron-dhcp-agent \
	  neutron-metadata-agent -y
}

# Function configure the server component
neutron_config_server_component () { 
	echocolor "Configure the server component"
	sleep 3
	neutronfile=/etc/neutron/neutron.conf
	neutronfilebak=/etc/neutron/neutron.conf.bak
	test -f $neutronfilebak || cp $neutronfile $neutronfilebak

	ops_del $neutronfile database connection 
	ops_add $neutronfile database connection mysql+pymysql://neutron:$NEUTRON_DBPASS@$CTL_EXT_IP/neutron

	ops_del $neutronfile DEFAULT core_plugin
	ops_add $neutronfile DEFAULT core_plugin ml2
	ops_add $neutronfile DEFAULT service_plugins router,qos,neutron.services.metering.metering_plugin.MeteringPlugin
	ops_add $neutronfile DEFAULT allow_overlapping_ips true
	ops_add $neutronfile DEFAULT router_distributed True
	ops_add $neutronfile DEFAULT advertise_mtu true

	ops_add $neutronfile DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$CTL_EXT_IP

	ops_add $neutronfile DEFAULT auth_strategy keystone
	ops_add $neutronfile keystone_authtoken auth_uri http://$CTL_EXT_IP:5000
	ops_add $neutronfile keystone_authtoken auth_url http://$CTL_EXT_IP:5000
	ops_add $neutronfile keystone_authtoken memcached_servers $CTL_EXT_IP:11211
	ops_add $neutronfile keystone_authtoken auth_type password
	ops_add $neutronfile keystone_authtoken project_domain_name default
	ops_add $neutronfile keystone_authtoken user_domain_name default
	ops_add $neutronfile keystone_authtoken project_name service
	ops_add $neutronfile keystone_authtoken username neutron
	ops_add $neutronfile keystone_authtoken password $NEUTRON_PASS

	ops_add $neutronfile DEFAULT notify_nova_on_port_status_changes true
	ops_add $neutronfile DEFAULT notify_nova_on_port_data_changes true
	ops_add $neutronfile nova auth_url http://$CTL_EXT_IP:5000
	ops_add $neutronfile nova auth_type password
	ops_add $neutronfile nova project_domain_name default
	ops_add $neutronfile nova user_domain_name default
	ops_add $neutronfile nova region_name RegionOne
	ops_add $neutronfile nova project_name service
	ops_add $neutronfile nova username nova
	ops_add $neutronfile nova password $NOVA_PASS
	
	ops_add $neutronfile qos notification_drivers message_queue
	ops_add $neutronfile oslo_concurrency lock_path /var/lib/neutron/tmp
}

# Function configure the Modular Layer 2 (ML2) plug-in
neutron_config_ml2 () {
	echocolor "Configure the Modular Layer 2 (ML2) plug-in"
	sleep 3
	ml2file=/etc/neutron/plugins/ml2/ml2_conf.ini
	ml2filebak=/etc/neutron/plugins/ml2/ml2_conf.ini.bak
	test -f $ml2filebak || cp $ml2file $ml2filebak

	ops_add $ml2file ml2 type_drivers flat,vlan,vxlan,gre
	ops_add $ml2file ml2 tenant_network_types vxlan,gre
	ops_add $ml2file ml2 mechanism_drivers openvswitch,l2population
	ops_add $ml2file ml2 extension_drivers port_security,qos
	ops_add $ml2file ml2_type_flat flat_networks provider
	ops_add $ml2file ml2_type_vlan network_vlan_ranges provider
	ops_add $ml2file ml2_type_vxlan vni_ranges 4000:8000
	ops_add $ml2file ml2_type_gre tunnel_id_ranges 2000:4000
	ops_add $ml2file securitygroup enable_ipset true
}

# Function configure the Open vSwitch agent
neutron_config_ovs () {
	echocolor "Configure the Open vSwitch agent"
	sleep 3
	ovsfile=/etc/neutron/plugins/ml2/openvswitch_agent.ini
	ovsfilebak=/etc/neutron/plugins/ml2/openvswitch_agent.ini.bak
	test -f $ovsfilebak || cp $ovsfile $ovsfilebak
	
	ops_add $ovsfile agent tunnel_types vxlan,gre
	ops_add $ovsfile agent l2_population True
	ops_add $ovsfile agent extensions qos
	ops_add $ovsfile agent enable_distributed_routing True
	ops_add $ovsfile ovs bridge_mappings provider:br-provider
	ops_add $ovsfile ovs local_ip $CTL_MGNT_IP	
	ops_add $ovsfile securitygroup firewall_driver openvswitch
}

# Function configure the L3 agent
neutron_config_l3 () {
	echocolor "Configure the L3 agent"
	l3file=/etc/neutron/l3_agent.ini
	l3filebak=/etc/neutron/l3_agent.ini.bak
	test -f $l3filebak || cp $l3file $l3filebak

	ops_add $l3file DEFAULT interface_driver openvswitch
	ops_add $l3file DEFAULT external_network_bridge
	ops_add $l3file DEFAULT ha_vrrp_auth_password password
	ops_add $l3file DEFAULT agent_mode dvr_snat
}

# Function configure the DHCP agent
neutron_config_dhcp () {
	echocolor "Configure the DHCP agent"
	sleep 3
	dhcpfile=/etc/neutron/dhcp_agent.ini
	dhcpfilebak=/etc/neutron/dhcp_agent.ini.bak
	test -f $dhcpfilebak || cp $dhcpfile $dhcpfilebak

	ops_add $dhcpfile DEFAULT interface_driver openvswitch
	ops_add $dhcpfile DEFAULT enable_isolated_metadata true
	ops_add $dhcpfile DEFAULT force_metadata True
}

# Function configure things relation
neutron_config_relation () {
	ovs-vsctl add-br br-provider
	ovs-vsctl add-port br-provider $CTL_EXT_IF
	ip a flush $CTL_EXT_IF
	ifconfig br-provider $CTL_EXT_IP netmask $CTL_EXT_NETMASK
	ip link set br-provider up
	ip r add default via $GATEWAY_EXT_IP
	echo "nameserver 8.8.8.8" > /etc/resolv.conf
	
	cat << EOF > /etc/network/interfaces
# loopback network interface
auto lo
iface lo inet loopback

auto br-provider
allow-ovs br-provider
iface br-provider inet static
    address $CTL_EXT_IP
    netmask $CTL_EXT_NETMASK
    gateway $GATEWAY_EXT_IP
    dns-nameservers 8.8.8.8
    ovs_type OVSBridge
    ovs_ports $CTL_EXT_IF

allow-br-provider $CTL_EXT_IF
iface $CTL_EXT_IF inet manual
    ovs_bridge br-provider
    ovs_type OVSPort

# internal network interface
auto $CTL_MGNT_IF
iface $CTL_MGNT_IF inet static
address $CTL_MGNT_IP
netmask $CTL_MGNT_NETMASK
EOF
}

# Function configure the metadata agent
neutron_config_metadata () {
	echocolor "Configure the metadata agent"
	sleep 3
	metadatafile=/etc/neutron/metadata_agent.ini
	metadatafilebak=/etc/neutron/metadata_agent.ini.bak
	test -f $metadatafilebak || cp $metadatafile $metadatafilebak

	ops_add $metadatafile DEFAULT nova_metadata_ip $CTL_EXT_IP
	ops_add $metadatafile DEFAULT metadata_proxy_shared_secret $METADATA_SECRET
}


# Function configure the Compute service to use the Networking service
neutron_config_compute_use_network () {
	echocolor "Configure the Compute service to use the Networking service"
	sleep 3
	novafile=/etc/nova/nova.conf

	ops_add $novafile neutron url http://$CTL_EXT_IP:9696
	ops_add $novafile neutron auth_url http://$CTL_EXT_IP:5000
	ops_add $novafile neutron auth_type password
	ops_add $novafile neutron project_domain_name default
	ops_add $novafile neutron user_domain_name default
	ops_add $novafile neutron region_name RegionOne
	ops_add $novafile neutron project_name service
	ops_add $novafile neutron username neutron
	ops_add $novafile neutron password $NEUTRON_PASS
	ops_add $novafile neutron service_metadata_proxy true
	ops_add $novafile neutron metadata_proxy_shared_secret $METADATA_SECRET
}

# Function populate the database
neutron_populate_db () {
	echocolor "Populate the database"
	sleep 3
	su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
	  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron
}

# Function restart installation
neutron_restart () {
	service nova-api restart
	service neutron-server restart
	service neutron-openvswitch-agent restart
	service neutron-dhcp-agent restart
	service neutron-metadata-agent restart
	service neutron-l3-agent restart
}

#######################
###Execute functions###
#######################

# Create database for Neutron
neutron_create_db

# Create the neutron service credentials
neutron_create_info

# Install the components
neutron_install

# Configure the server component
neutron_config_server_component

# Configure the Modular Layer 2 (ML2) plug-in
neutron_config_ml2

# Configure the Open vSwitch agent
neutron_config_ovs

# Configure the L3 agent
neutron_config_l3
	
# Configure the DHCP agent
neutron_config_dhcp

# Configure things relation
neutron_config_relation

# Configure the metadata agent
neutron_config_metadata

# Configure the Compute service to use the Networking service
neutron_config_compute_use_network

# Populate the database
neutron_populate_db

# Function restart installation
neutron_restart