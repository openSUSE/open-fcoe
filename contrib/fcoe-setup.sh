#!/bin/bash
#
# fcoe-setup.sh
#
# Create VLAN interface for FCoE
#

check_ifcfg () {
    local vif=$1
    local ifname=$2
    local ifcfg=/etc/sysconfig/network/ifcfg-$vif

    if [ -f "$ifcfg" ] ; then
	echo "Interface is configured properly"
    else
	echo "Creating ifcfg configuration ifcfg-$vif"
	cat > $ifcfg <<EOF
BOOTPROTO="static"
STARTMODE="onboot"
ETHERDEVICE="$ifname"
USERCONTROL="no"
INTERFACETYPE="vlan"
EOF
    fi
}

check_fcoe () {
    local vif=$1
    local fcoecfg=/etc/fcoe/cfg-$vif

    if [ -f "$fcoecfg" ] ; then
	echo "FCoE is configured properly"
    else
	echo "Creating FCoE configuration cfg-$vif"
	cat > $fcoecfg <<EOF
FCOE_ENABLE="yes"
DCB_REQUIRED="yes"
EOF
    fi
}

ifname=$1
if [ -z "$ifname" ] ; then
    echo "No Interface given!"
    exit 1
fi
if [ ! -d /sys/class/net/$ifname ] ; then
    echo "Interface $ifname does not exist!"
    exit 2
fi

modprobe 8021q
ip link set $ifname up
fipvlan -c -s $ifname
vif=$(sed -n 's/\([^ ]*\) *.*eth2/\1/p' /proc/net/vlan/config)
check_ifcfg $vif $ifname
check_fcoe $vif

exit 0
