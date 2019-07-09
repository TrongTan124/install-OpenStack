#!/bin/bash
#Author Nguyen Trong Tan

source function.sh
source config.sh

# Function create database for octavia
octavia_create_db () {
	echocolor "Create database for octavia"
	sleep 3

	cat << EOF | mysql
CREATE DATABASE octavia;

GRANT ALL PRIVILEGES ON octavia.* TO 'octavia'@'localhost' IDENTIFIED BY '$OCTAVIA_DBPASS';
GRANT ALL PRIVILEGES ON octavia.* TO 'octavia'@'%' IDENTIFIED BY '$OCTAVIA_DBPASS';

FLUSH PRIVILEGES;
EOF
}

# Function create infomation for Container service
octavia_create_info () {
	echocolor "Set environment variable for user admin"
	source /root/admin-openrc
	
	echocolor "Create infomation for LBaaS service"
	sleep 3

	## Create info for octavia user
	echocolor "Create info for octavia user"
	sleep 3

	openstack user create --domain default --password $OCTAVIA_PASS octavia
	openstack role add --project service --user octavia admin
	openstack service create --name octavia --description "OpenStack Load Balancer" load-balancer
	
	openstack endpoint create --region RegionOne load-balancer public http://$CTL_EXT_IP:9876/
	openstack endpoint create --region RegionOne load-balancer internal http://$CTL_EXT_IP:9876/
	openstack endpoint create --region RegionOne load-balancer admin http://$CTL_EXT_IP:9876/

}

function config_neutron_lbaasv2 ()
{
    echocolor "Configuring Neutron LBaaSv2"
    sleep 5
	
    datenow=$(date +"%d%m%Y")

    neutron_server_cfg=/etc/default/neutron-server
    cp $neutron_server_cfg $neutron_server_cfg.bak.$datenow
	
    cat << EOF >> /etc/default/neutron-server
DAEMON_ARGS="\$DAEMON_ARGS --config-file=/etc/neutron/neutron_lbaas.conf --config-file=/etc/neutron/services_lbaas.conf"
EOF

    neutron_cfg=/etc/neutron/neutron.conf
	neutron_bak=$neutron_cfg.bak.$datenow
    cp $neutron_cfg $neutron_bak

    echocolor "Config file neutron.conf"
    sleep 5
    
    SERVICEPLUGIN=`egrep "^service_plugins" $neutron_bak |awk '{ print $3 }'`
    ops_add $neutron_cfg DEFAULT service_plugins $SERVICEPLUGIN,neutron_lbaas.services.loadbalancer.plugin.LoadBalancerPluginv2
	
    ops_add $neutron_cfg service_providers service_provider LOADBALANCERV2:Octavia:neutron_lbaas.drivers.octavia.driver.OctaviaDriver:default
    ops_add $neutron_cfg service_auth auth_url http://$VIP_MGNT_IP:5000
    ops_add $neutron_cfg service_auth admin_user octavia
    ops_add $neutron_cfg service_auth admin_tenant_name service
    ops_add $neutron_cfg service_auth admin_password $OCTAVIA_PASS
    ops_add $neutron_cfg service_auth admin_user_domain default
    ops_add $neutron_cfg service_auth admin_project_domain default
    ops_add $neutron_cfg service_auth region $REGION
    ops_add $neutron_cfg service_auth auth_version 3
	
    neutron_lb_cfg=/etc/neutron/services_lbaas.conf
    cp $neutron_lb_cfg $neutron_lb_cfg.bak.$datenow
	
    ops_add $neutron_lb_cfg octavia base_url http://$VIP_MGNT_IP:9876/
	
    # Add hostname Octavia
    for i in `seq 2`; do
        host=`cat $(dirname $0)/config.cfg | grep -E OCTAVIA\$i.HOSTNAME | awk -F\' '{print $2}'`
        short_host=`echo $host | awk -F. '{print $1}'`
        ip=`cat $(dirname $0)/config.cfg | grep -E OCTAVIA\$i.MNGT_IP | awk -F\' '{print $2}'`
        echo "$ip    $host    $short_host" >> /etc/hosts
    done
	
    # Config HAproxy
    cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.$datenow

    cat << EOF >> /etc/haproxy/haproxy.cfg


listen octavia-api
    bind $VIP_MGNT_IP:9876 
    option  httpchk
    option  httplog
    option  httpclose
    timeout server  600s
    server controller1 $OCTAVIA1_MNGT_IP:9876 check inter 10s fastinter 2s downinter 3s rise 3 fall 3
    server controller2 $OCTAVIA2_MNGT_IP:9876 check inter 10s fastinter 2s downinter 3s rise 3 fall 3
EOF

}    # ----------  end of function neutron lbaasv2  ----------

# Reload resource pacemaker

function update_db ()
{
    echocolor "Sync DB Neutron to update LBaasv2"
	sleep 5
	neutron-db-manage --config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head
}

function restart_services ()
{
    echocolor "Restarting Neutron API service ..."
    sleep 5
	
    service neutron-lbaasv2-agent stop
	
    service neutron-server restart
		
    # remove lbaasv2 agent
    update-rc.d -f neutron-lbaasv2-agent.service remove

}    # ----------  end of function restart_services  ----------


# Function install components of octavia
octavia_install () {
	echocolor "Install and configure components of octavia"
	sleep 3
	apt -y install neutron-lbaasv2-agent 
	
	apt -y install python-pip bc
	
	pip install python-octaviaclient==1.9.0
	
	pushd /root
	git clone https://opendev.org/openstack/octavia.git --branch stable/stein
	pushd octavia
	pip install -r requirements.txt -e .
	popd
	popd
		
}

function build_image ()
{

    echocolor "Import environment"
    sleep 5
	source /root/admin-openrc
	
	apt install -y qemu uuid-runtime curl kpartx git jq debootstrap
	pip install argparse Babel>=1.3 dib-utils PyYAML
	pushd /tmp
	git clone https://opendev.org/openstack/octavia.git --branch stable/stein
	git clone https://opendev.org/openstack/diskimage-builder.git stable/stein
	pushd octavia/diskimage-create
	./diskimage-create.sh
	mv amphora-x64-haproxy.qcow2 /tmp
	popd
	popd
	
	openstack image create "amphora-x64-haproxy" \
	--file /tmp/amphora-x64-haproxy.qcow2 \
	--disk-format qcow2 --tag amphora \
	--container-format bare --public

}

# Function config /etc/octavia/octavia.conf file
octavia_config_prepare () {
#	octaviafile=/etc/octavia/octavia.conf
#	octaviafilebak=/etc/octavia/octavia.conf.bak
#	test -f $octaviafilebak || cp $octaviafile $octaviafilebak
	mkdir -p /etc/octavia
	mkdir -p /etc/octavia/.ssh
	mkdir -p /etc/octavia/certs
	mkdir -p /var/log/octavia
	
	openstack flavor create --private --id auto --ram 1024 --disk 4 --vcpus 2 amphora
	
	ssh-keygen -b 2048 -t rsa -N "" -f /etc/octavia/.ssh/octavia
	openstack keypair create --public-key /etc/octavia/.ssh/octavia.pub octavia
	
	pushd /root
	sed -i 's/foobar/'"$PASS_SSL"'/g' ./octavia/bin/create_certificates.sh
	./octavia/bin/create_certificates.sh /etc/octavia/certs ~/octavia/etc/certificates/openssl.cnf
	popd
	
	openstack security group create lb-mgmt-sec-grp
	openstack security group rule create --protocol icmp lb-mgmt-sec-grp
	openstack security group rule create --protocol tcp --dst-port 22 lb-mgmt-sec-grp
	openstack security group rule create --protocol tcp --dst-port 9443 lb-mgmt-sec-grp
	openstack security group rule create --protocol icmpv6 --ethertype IPv6 --remote-ip ::/0 lb-mgmt-sec-grp
	openstack security group rule create --protocol tcp --dst-port 22 --ethertype IPv6 --remote-ip ::/0 lb-mgmt-sec-grp
	openstack security group rule create --protocol tcp --dst-port 9443 --ethertype IPv6 --remote-ip ::/0 lb-mgmt-sec-grp
	
}

octavia_config_all () {

    cp ~/octavia/etc/octavia.conf /etc/octavia/octavia.conf	
    cp ~/octavia/etc/policy/admin_or_owner-policy.json /etc/octavia/policy.json
	
	FLAVOR_ID=`openstack flavor list --all |grep 'amphora' | awk '{print $2}'`
	
	ops_add /etc/octavia/octavia.conf controller_worker amp_flavor_id $FLAVOR_ID
	ops_add /etc/octavia/octavia.conf controller_worker amp_ssh_key_name octavia
	
	ops_add /etc/octavia/octavia.conf certificates ca_certificate /etc/octavia/certs/ca_01.pem
	ops_add /etc/octavia/octavia.conf certificates ca_private_key /etc/octavia/certs/private/cakey.pem
	ops_add /etc/octavia/octavia.conf certificates ca_private_key_passphrase $PASS_SSL
	ops_add /etc/octavia/octavia.conf haproxy_amphora client_cert /etc/octavia/certs/client.pem
	ops_add /etc/octavia/octavia.conf haproxy_amphora server_ca /etc/octavia/certs/ca_01.pem
	ops_add /etc/octavia/octavia.conf haproxy_amphora base_path /var/lib/octavia
	ops_add /etc/octavia/octavia.conf haproxy_amphora base_cert_dir /var/lib/octavia/certs
	ops_add /etc/octavia/octavia.conf haproxy_amphora connection_max_retries 1500
	ops_add /etc/octavia/octavia.conf haproxy_amphora connection_retry_interval 1
	
	ops_add /etc/octavia/octavia.conf controller_worker amp_boot_network_list $NETWORK_OCTAVIA_MNGT_ID
	
	ops_add /etc/octavia/octavia.conf health_manager controller_ip_port_list $CTL_EXT_IP:5555
	ops_add /etc/octavia/octavia.conf health_manager bind_ip $CTL_EXT_IP
	ops_add /etc/octavia/octavia.conf health_manager bind_port 5555
	ops_add /etc/octavia/octavia.conf health_manager heartbeat_key insecure.
	
	SECURITY_GRP_ID=`openstack security group list |grep 'lb-mgmt-sec-grp' | awk '{print $2}'`
	
	ops_add /etc/octavia/octavia.conf controller_worker amp_secgroup_list $SECURITY_GRP_ID	
	ops_add /etc/octavia/octavia.conf controller_worker amp_image_tag amphora	
	ops_add /etc/octavia/octavia.conf controller_worker amp_active_retries 9999
	ops_add /etc/octavia/octavia.conf controller_worker amphora_driver amphora_haproxy_rest_driver
	ops_add /etc/octavia/octavia.conf controller_worker compute_driver compute_nova_driver
	ops_add /etc/octavia/octavia.conf controller_worker network_driver allowed_address_pairs_driver	
	ops_add /etc/octavia/octavia.conf controller_worker loadbalancer_topology ACTIVE_STANDBY
	
	ops_add /etc/octavia/octavia.conf keystone_authtoken auth_uri http://$CTL_EXT_IP:5000
	ops_add /etc/octavia/octavia.conf keystone_authtoken auth_url http://$CTL_EXT_IP:5000
	ops_add /etc/octavia/octavia.conf keystone_authtoken memcached_servers $CTL_EXT_IP:11211
	ops_add /etc/octavia/octavia.conf keystone_authtoken auth_type password
	ops_add /etc/octavia/octavia.conf keystone_authtoken project_domain_name default
	ops_add /etc/octavia/octavia.conf keystone_authtoken user_domain_name default
	ops_add /etc/octavia/octavia.conf keystone_authtoken project_name service
	ops_add /etc/octavia/octavia.conf keystone_authtoken username octavia
	ops_add /etc/octavia/octavia.conf keystone_authtoken password $OCTAVIA_PASS
	
	ops_add /etc/octavia/octavia.conf service_auth memcached_servers $CTL_EXT_IP:11211
	ops_add /etc/octavia/octavia.conf service_auth project_domain_name Default
	ops_add /etc/octavia/octavia.conf service_auth project_name admin
	ops_add /etc/octavia/octavia.conf service_auth user_domain_name Default
	ops_add /etc/octavia/octavia.conf service_auth password $ADMIN_PASS
	ops_add /etc/octavia/octavia.conf service_auth username admin
	ops_add /etc/octavia/octavia.conf service_auth auth_type password
	ops_add /etc/octavia/octavia.conf service_auth auth_url http://$CTL_EXT_IP:5000
	
	ops_add /etc/octavia/octavia.conf DEFAULT transport_url rabbit://openstack:$RABBIT_PASS@$CTL_EXT_IP:5672
	ops_add /etc/octavia/octavia.conf oslo_messaging topic octavia_prov
	ops_add /etc/octavia/octavia.conf oslo_messaging event_stream_transport_url rabbit://openstack:$RABBIT_PASS@$CTL_EXT_IP:5672
	
	ops_add /etc/octavia/octavia.conf api_settings bind_host 0.0.0.0
	ops_add /etc/octavia/octavia.conf api_settings bind_port 9876
	ops_add /etc/octavia/octavia.conf api_settings api_handler queue_producer
	ops_add /etc/octavia/octavia.conf api_settings auth_strategy keystone
	
	ops_add /etc/octavia/octavia.conf database connection mysql+pymysql://octavia:$OCTAVIA_DBPASS@$CTL_EXT_IP/octavia

}


# Function populate the octavia-api database
octavia_populate_octavia_db () {
echocolor "Populate the octavia-api database"
sleep 3
/usr/local/bin/octavia-db-manage --config-file=/etc/octavia/octavia.conf upgrade head
}

function config_startup ()
{

	cp octavia-api /etc/init.d/octavia-api
	cp octavia-health-manager /etc/init.d/octavia-health-manager
	cp octavia-housekeeping /etc/init.d/octavia-housekeeping
	cp octavia-worker /etc/init.d/octavia-worker
	
	chmod +x /etc/init.d/octavia-*
	
	cp octavia-api.service /lib/systemd/system/octavia-api.service
	cp octavia-health-manager.service /lib/systemd/system/octavia-health-manager.service
	cp octavia-housekeeping.service /lib/systemd/system/octavia-housekeeping.service
	cp octavia-worker.service /lib/systemd/system/octavia-worker.service
	
	systemctl enable octavia-api.service 
	systemctl enable octavia-worker.service
	systemctl enable octavia-housekeeping.service
	systemctl enable octavia-health-manager.service
}

function restart_services ()
{
    echocolor "Restarting Octavia service ..."
    sleep 5
	
	systemctl restart octavia-api.service 
	systemctl restart octavia-worker.service
	systemctl restart octavia-housekeeping.service
	systemctl restart octavia-health-manager.service

}    # ----------  end of function restart_services  ----------

function verify ()
{
    echocolor "Verify Octavia Service"
    sleep 20
    source /root/admin-openrc
    openstack loadbalancer list

}    # ----------  end of function verify  ----------

#######################
###Execute functions###
#######################

# Create database for octavia
octavia_create_db

# Create infomation for Compute service
octavia_create_info

# Install components of octavia
octavia_install

# Config /etc/octavia/octavia.conf file
octavia_config_prepare

# Config /etc/octavia/octavia.conf file
octavia_config_all

# Populate the octavia-api database
octavia_populate_octavia_db

# Restart installation
octavia_restart