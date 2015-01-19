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
    local retry vif_down vif_offline
    local vif_down_old vif_offline_old

    if [ -z "if_list" ] ; then
	echo "No FCoE interfaces"
	return
    fi
    echo "Starting FCoE on $if_list"
    sleep $fcoe_delay
    vif_list=$(/usr/sbin/fipvlan --start --create $if_list --link-retry=$retry_count | sed -n 's/\(eth[0-9]*\) *| \([0-9]*\) *|.*/\1.\2/p')
    if [ -z "$vif_list" ] ; then
	echo "No FCoE interfaces created; dropping to /bin/sh"
	cd /
	PATH=$PATH PS1='$ ' /bin/sh -i
    fi
    echo -n "Waiting for FCoE on $vif_list: "
    vif_down_old=0
    vif_offline_old=0
    while [ $retry_count -gt 0 ] ; do
	retry=0
	found=0
	vif_down=0
	vif_offline=0
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
	    if [ "$status" = "Linkdown" ] ; then
		echo -n "|"
		vif_down=$(($vif_down + 1));
	    elif [ "$status" = "Online" ] ; then
		found=1;
		continue;
	    else
		echo -n "."
		vif_offline=$(($vif_offline + 1))
	    fi
	    retry=$(($retry + 1));
	done
	[ $retry -eq 0 ] || [ $found -eq 1 ] && break;
	if [ $vif_down -eq $vif_down_old ] &&
	    [ $vif_offline -eq $vif_offline_old ] ; then
            retry_count=$(($retry_count-1))
	fi
	vif_down_old=$vif_down
	vif_offline_old=$vif_offline
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
