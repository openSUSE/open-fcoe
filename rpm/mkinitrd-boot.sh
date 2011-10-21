#!/bin/bash
#%stage: device
#%depends: network lldpad
#%programs: /usr/sbin/fipvlan /usr/sbin/fcoeadm /sbin/vconfig /sbin/ip
#%modules: $fcoe_drv 8021q
#%if: "$root_fcoe"
#
##### FCoE initialization
##
## This script initializes FCoE (FC over Ethernet).

load_modules

create_fcoe_vlan()
{
    local if=$1
    local vlan=$2
    local vif=$3

    vconfig add $if $vlan
    tmp_vif=$(sed -n "s/\([^ ]*\).*${vlan}.*${if}/\1/p" /proc/net/vlan/config)
    if [ "$vif" ] && [ "$tmp_vif" != "$vif" ] ; then
	ip link set dev $tmp_vif name $vif
    fi
    wait_for_events
    dcbtool sc $if dcb on > /dev/null 2>&1
    dcbtool sc $if app:fcoe e:1 > /dev/null 2>&1
    ip link set $if up
    ip link set $vif up
}

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

    for h in /sys/class/net/$ifname/host* ; do
	[ -d "$h" ] || continue
	echo ${h##*/}
	break
    done
}

wait_for_fcoe_if()
{
    local ifname=$1
    local host vif
    local retry_count=$udev_timeout

    vif=$(lookup_vlan_if $ifname)
    if [ -z "$vif" ] ; then
	echo "No VLAN interface created on $ifname"
	echo "dropping to /bin/sh"
	cd /
	PATH=$PATH PS1='$ ' /bin/sh -i
    fi
    host=$(lookup_fcoe_host $vif)
    if [ "$host" ] ; then
	echo -n "Wait for FCoE link on $vif: "
	while [ $retry_count -gt 0 ] ; do
	    status=$(cat /sys/class/fc_host/$host/port_state 2> /dev/null)
	    if [ "$status" = "Online" ] ; then
		echo "Ok"
		return 0
	    fi
	    echo -n "."
            retry_count=$(($retry_count-1))
            sleep 2
	done
	echo -n "Failed; "
    else
	echo -n "FC host not created; "
    fi

    echo "dropping to /bin/sh"
    cd /
    PATH=$PATH PS1='$ ' /bin/sh -i
}

for if in "$fcoe_if" ; do
    ip link set $if up
    /usr/sbin/fipvlan -c -s $if
    wait_for_fcoe_if $if
done
if [ -n "$edd_if" ] ; then
    ip link set $edd_if up
    /usr/sbin/fipvlan -c -s $edd_if
    wait_for_fcoe_if $edd_if
fi
