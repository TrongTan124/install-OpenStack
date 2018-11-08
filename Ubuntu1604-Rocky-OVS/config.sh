#!/bin/bash
#Author Nguyen Trong Tan

##########################################
#### Set local variable  for scripts #####
##########################################

echocolor "Set local variable for scripts"
sleep 3

# Network model (provider or selfservice)
network_model=selfservice

#  Ipaddress variable and Hostname variable
## Assigning IP for controller node
CTL_EXT_IP=172.16.69.175
CTL_EXT_NETMASK=255.255.255.0
CTL_EXT_IF=ens3
CTL_MGNT_IP=20.20.30.175
CTL_MGNT_NETMASK=255.255.255.0
CTL_MGNT_IF=ens4

## Assigning IP for Compute1 host
COM1_EXT_IP=172.16.69.176
COM1_EXT_NETMASK=255.255.255.0
COM1_EXT_IF=ens3
COM1_MGNT_IP=20.20.30.176
COM1_MGNT_NETMASK=255.255.255.0
COM1_MGNT_IF=ens4

## Assigning IP for Compute2 host
COM2_EXT_IP=172.16.69.177
COM2_EXT_NETMASK=255.255.255.0
COM2_EXT_IF=ens3
COM2_MGNT_IP=20.20.30.177
COM2_MGNT_NETMASK=255.255.255.0
COM2_MGNT_IF=ens4

## Gateway for EXT network
GATEWAY_EXT_IP=172.16.69.1
CIDR_EXT=172.16.69.0/24
CIDR_MGNT=20.20.30.0/24

## Hostname variable
HOST_CTL=controller
HOST_COM1=compute1
HOST_COM2=compute2

# Password variable
DEFAULT_PASS="Welcome123"

ADMIN_PASS=$DEFAULT_PASS
DEMO_PASS=$DEFAULT_PASS
RABBIT_PASS=$DEFAULT_PASS
KEYSTONE_DBPASS=$DEFAULT_PASS	
GLANCE_DBPASS=$DEFAULT_PASS	
GLANCE_PASS=$DEFAULT_PASS	
METADATA_SECRET=$DEFAULT_PASS	
NEUTRON_DBPASS=$DEFAULT_PASS	
NEUTRON_PASS=$DEFAULT_PASS	
NOVA_PASS=$DEFAULT_PASS	
NOVA_DBPASS=$DEFAULT_PASS	
PLACEMENT_PASS=$DEFAULT_PASS	