#!/bin/bash
#Author Nguyen Trong Tan

source function.sh
source config.sh

if [ $network_model = "provider" -o $network_model = "selfservice" ]
then
	echo -e "\e[32mScripts start install \e[0m"
else
	echo -e "\e[31mConfiguring network_model variable was incorrect in file config.sh, network_model=\e[0m\e[1;43;31mprovider\e[0m \e[31mor\e[0m \e[1;43;31mselfservice\e[0m"
	exit 1;
fi

source function.sh
source config.sh

echocolor "IP address"
source com1-0-ipaddr.sh

echocolor "Environment"
source com1-1-environment.sh

echocolor "Nova"
source com1-2-nova.sh

if [ $network_model = "provider" ]
then
	echocolor "Neutron"
	source com1-3-neutron-provider.sh
elif [ $network_model = "selfservice" ]
then
	echocolor "Neutron"
	source com1-3-neutron-selfservice.sh
fi



