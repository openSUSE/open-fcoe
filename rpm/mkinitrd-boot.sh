#!/bin/bash
#%stage: device
#%depends: network lldpad
#%programs: /usr/sbin/fipvlan /usr/sbin/fcoeadm
#%modules: $fcoe_drv 8021q
#%if: "$root_fcoe"
#
##### FCoE initialization
##
## This script initializes FCoE (FC over Ethernet).

load_modules

lookup_vlan_if()
{
    local ifname=$1
    local vlan vid if

    IFS="| "; while read vlan vid if; do
	[ "${vlan%% Dev*}" = "VLAN" ] && continue
	[ -z "$vid" ] && continue
	if [ "$if" = "$ifname" ] ; then
	    echo $vlan
	fi
    done < /proc/net/vlan/config
}

lookup_fcoe_host()
{
    local ifname=$1
    local h

    for h in /sys/class/fc_host/host* ; do
	[ -d "$h" ] || continue
	[ -e $h/symbolic_name ] || continue
	vif=$(sed -n 's/.* over \(.*\)/\1/p' $h/symbolic_name)
	if [ "$vif" ] && [ "$ifname" = "$vif" ] ; then
	    echo ${h##*/}
	    break
	fi
    done
}

wait_for_fcoe_if()
{
    local if_list=$1
    local host vif
    local retry_count=$udev_timeout
    local retry

    vif_list=$(/usr/sbin/fipvlan --start --create $if_list | sed -n 's/\(eth[0-9]*\) *| \([0-9]*\) *|.*/\1.\2/p')
    echo -n "Waiting for FCoE on $vif_list: "
    while [ $retry_count -gt 0 ] ; do
	retry=0
	found=0
	for vif in $vif_list ; do
	    if [[ $vif =~ eth[0-9]+\.0$ ]]; then
		vif=$(echo $vif | sed -n -e 's/\(eth[0-9]\+\).0$/\1/p')
	    fi
	    if ! ip link show $vif > /dev/null 2>&1 ; then
		echo -n "O"
		retry=$(($retry + 1));
		continue;
	    fi
	    host=$(lookup_fcoe_host $vif)
	    if [ -z "$host" ] ; then
		echo -n "o"
		retry=$(($retry + 1));
		continue;
	    fi
	    status=$(cat /sys/class/fc_host/$host/port_state 2> /dev/null)
	    if [ "$status" = "Online" ] ; then
		found=1;
		continue;
	    fi
	    echo -n "."
	    retry=$(($retry + 1));
	done
	[ $retry -eq 0 ] || [found -eq 1 ] && break;
        retry_count=$(($retry_count-1))
        sleep 2
    done
    if [ $retry_count -eq 0 -a $retry -gt 0 ] ; then
	echo "timeout; dropping to /bin/sh"
	cd /
	PATH=$PATH PS1='$ ' /bin/sh -i
    else
	echo "Ok"
    fi
}

wait_for_fcoe_if "$fcoe_if $edd_if"
