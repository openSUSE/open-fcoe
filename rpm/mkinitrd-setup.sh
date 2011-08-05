#!/bin/bash
#
#%stage: device
#

check_fcoe_root() {
    local devname=${1##/dev/}
    local sysfs_path

    if [ -d /sys/block/$devname/device ] ; then
	sysfs_path=$(cd -P /sys/block/$devname/device 2> /dev/null; echo $PWD)
    fi
    if [ -z "$sysfs_path" ] ; then
	return;
    fi

    case "$sysfs_path" in
        *rport-*)
                shost_path=${sysfs_path%%/rport-*}
                shost=${shost_path##*/}
                ;;
    esac

    if [ -n "$shost_path" ] && [ -d "${shost_path}/fc_host/$shost" ] ; then
        if grep -q fcoe $shost_path/fc_host/$shost/symbolic_name ; then
	    ifpath=${shost_path%/host*}
	    ifname=${ifpath##*/}
	    echo "$ifname"
        fi
    fi
}

for bd in $blockdev; do
    update_blockdev $bd
    ifname="$(check_fcoe_root $bd)"
    if [ "$ifname" ]; then
	if [ -f /proc/net/vlan/$ifname ] ; then
	    fcoe_vif=$ifname
	    fcoe_if=$(sed -n 's/Device: \(.*\)/\1/p' /proc/net/vlan/$ifname)
	    fcoe_vlan=$(sed -n 's/.*VID: \([0-9]*\).*/\1/p' /proc/net/vlan/$ifname)
	else
	    fcoe_if=$ifname
	    fcoe_vif=$ifname
	fi
    	root_fcoe=1
        # This can break, but network does not support more interfaces for now
        if [ -z "$interface" ] ; then
            interface="$fcoe_if"
        fi
    fi
done

save_var root_fcoe
save_var fcoe_if
save_var fcoe_vif
save_var fcoe_vlan

if [ "${root_fcoe}" ] ; then
    # Create /usr/sbin directory if not present
    [ -d $tmp_mnt/usr/sbin ] || mkdir -p $tmp_mnt/usr/sbin
    cp /etc/hba.conf ${tmp_mnt}/etc
    libhbalinux=$(sed -n 's/org.open-fcoe.libhbalinux *\(.*\)/\1/p' /etc/hba.conf)
    if [ "$libhbalinux" ] ; then
	cp $libhbalinux ${tmp_mnt}$libhbalinux
    fi
    if [ -f "/etc/fcoe/cfg-${fcoe_vif}" ] ; then
        # copy the fcoe configuration
	mkdir $tmp_mnt/etc/fcoe
	cp /etc/fcoe/cfg-${fcoe_vif} ${tmp_mnt}/etc/fcoe
    fi
fi
