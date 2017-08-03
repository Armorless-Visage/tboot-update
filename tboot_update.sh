#/usr/bin/env bash
# Liam Nolan 2017 (c) BSD 2-Clause

# this creates a tpm mle policy and writes it into the bios nvram
# it is desgined to work with TPM 1.2 and tested on older circa 2010 Dell hardware
# running Fedora 25

# you should put your own kernel line, version and tpm ownerpass below to replace
# the provided examples

# after updating your kernel(at your package managers update time check history) 
# place the lastest kernel version below and run this script eg. sh ./tboot_update.sh
# to put the latest kernel hash into TPM nvram memory

# I found the fedora25 repo version of tboot was old and buggy, the latest version
# of tboot(.gz) was required from the project site 
# https://sourceforge.net/projects/tboot/

# WARNING this script will write tpm nvram areas!
# WARNING this script will attempt to restart tcsd using systemctl
# WARNING this script will call grub2-mkconfig -o /boot/grub2/grub.cfg


## VARS
latest_kernel="4.10.11-200.fc25.x86_64"

kernel_line="root=/dev/mapper/volgroup-rootvol ro rd.lvm.lv=volgroup/rootvol rd.luks.uuid=luks-6de17249-e365-4bc7-93e8-80e113d753c5 rd.lvm.lv=volgroup/swapvol rd.lvm.lv=volgroup/uservol rhgb quiet audit=1 intel_iommu=on"
tpm_ownerpass="TPMOWNERPASSWORD"

tboot_options="logging=vga,memory vga_delay=2"
tboot_location="/boot/tboot.gz"


# move files from running this script previously to .tboot_old
echo "starting tboot tpm policy update"
if [ -d .tboot_old ]; then
	echo "moving old policy files to .tboot_old/"
	mv mle_hash vl.pol lcp.pol .tboot_old
else
	echo "creating .tboot_old/"
	mkdir .tboot_old
	echo "moving old policy files to .tboot_old/"
	mv mle_hash vl.pol lcp.pol .tboot_old
fi

# create vl.pol with kernel vmlinuz, initramfs, and boot line
echo ""
echo "started vl policy creation"
tb_polgen --create --type halt vl.pol &&
tb_polgen --add --num 0 --pcr none --hash image --cmdline "$kernel_line" --image /boot/vmlinuz-$latest_kernel vl.pol &&
echo "wrote kernel and kernel cmdline to policy file (vl.pol) OK"  
tb_polgen --add --num 1 --pcr 19 --hash image --cmdline "" --image /boot/initramfs-$latest_kernel.img vl.pol &&
echo "wrote initramfs @pcr19 to policy file (vl.pol) OK"
echo ""

# create a measured launch enviroment
echo "started creating launch control policy"
lcp_mlehash -c "$tboot_options" $tboot_location > mle_hash &&
lcp_crtpol -v 1 -t hashonly -m mle_hash -o lcp.pol &&
echo "mle_hash wrote to lcp.pol OK"
echo ""

# systemd restart tcsd
echo "attempting systemctl restart of tcsd(need this daemon to to talk to the TPM)"
systemctl restart tcsd &&
echo "tcsd restarted OK"
echo ""

# write policy to tpm nvram
echo "releasing tpm nvram"
tpmnv_relindex -i owner -p $tpm_ownerpass &&
tpmnv_relindex -i 0x20000001 -p $tpm_ownerpass && 
tpmnv_relindex -i 0x20000002 -p $tpm_ownerpass &&
echo "released tpm nvram OK"
echo "redefining nvram areas"
tpmnv_defindex -i owner -p $tpm_ownerpass &&
tpmnv_defindex -i 0x20000001 -s "$(cat vl.pol | wc -c)" -pv 0x02 -p $tpm_ownerpass &&
tpmnv_defindex -i 0x20000002 -s 8 -pv 0 -rl 0x07 -wl 0x07 -p $tpm_ownerpass &&
echo "defined tpm nvram areas OK"
echo "starting lcp_writepol" 
lcp_writepol -i owner -f lcp.pol -p $tpm_ownerpass &&
lcp_writepol -i 0x20000001 -f vl.pol -p $tpm_ownerpass &&
echo "wrote policy to the TPM OK"
echo ""

# make grub2 update tboot entries
echo "calling grub2-mkconfig to inform grub of the updates"
grub2-mkconfig -o /boot/grub2/grub.cfg &&
echo "Done tboot update!"
