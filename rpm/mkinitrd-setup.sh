#!/bin/bash
#
#%stage: device
#

# Default DCB startup delay
fcoe_delay=30

get_fc_host() {
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
	echo "$shost_path"
    fi
}

get_fcoe_drvname() {
    local shost_path=$1
    local shost=${shost_path##*/}
    local sysfs_path

    fcoe_name=$(cat $shost_path/fc_host/$shost/symbolic_name)
    case $fcoe_name in
	*over*)
	    echo "$fcoe_name"
	    ;;
    esac
}

for bd in $blockdev; do
    update_blockdev $bd
    shost_path="$(get_fc_host $bd)"
    if [ "$shost_path" ]; then
	symname="$(get_fcoe_drvname $shost_path)"
	ifname=${symname#* over }
	cur_drv=${symname%% *}
	found=0
	for d in $fcoe_drv ; do
	    [ "$d" = "$cur_drv" ] && found=1
	done
	if [ "$found" = "0" ] ; then
	    fcoe_drv="$fcoe_drv $cur_drv"
	fi
	if [ -f /proc/net/vlan/$ifname ] ; then
	    cur_if=$(sed -n 's/Device: \(.*\)/\1/p' /proc/net/vlan/$ifname)
	else
	    cur_if=$ifname
	fi
	found=0
	for i in $fcoe_if ; do
	    [ "$i" = "$cur_if" ] && found=1
	done
	if [ "$found" = "0" ] ; then
	    fcoe_if="$fcoe_if $cur_if"
	fi
	pci_path=${shost_path%/*}
	case "$pci_path" in
	    *virtual*)
		pci_path="/sys/class/net/$cur_if/device"
		;;
	esac
	pci_drv=$(readlink $pci_path/driver)
	for d in $drvlink ; do
	    [ "$d" = "$pci_drv" ] && found=1
	done
	if [ "$found" = 0 ] ; then
	    drvlink="$drvlink ${pci_drv##*/}"
	fi
	root_fcoe=1
    fi
done

save_var root_fcoe
save_var fcoe_if
save_var fcoe_drv
save_var drvlink
save_var fcoe_delay

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
