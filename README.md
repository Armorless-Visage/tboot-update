# tboot 1.2 policy update script

This script is so I can update tboot mle policy with the latest kernels hash.

It is for TPM1.2 devices and uses a v1 launch control policy, so it will not 
work with newer v2 lcp devices. 

This did not work using the fedora provided package managers version of tboot,
had to go to the sourceforge page of the tboot project and download/install
that version to get tboot working. 

https://sourceforge.net/projects/tboot/

## description

The script will create a verified launch policy, add the initramfs and vmlinuz
version in /boot specified by 'lastest_kernel', hash to the policy. It will
then create a mle_hash of /boot/tboot.gz and make a launch control policy out
of the tboot_options.

It runs systemd 'systemctl reboot tcsd' to attempt to make sure
tcsd is on (it is needed to talk to the tpm)

Then it releases tpm nvram areas of owner index, 0x20000001 and 0x20000002,
redefines those areas with the size of the newly created vl.pol and writes
vl.pol and lcp.pol to the memory.

Once everything is complete, run 'grub2-mkconfig -o /boot/grub2/grub.cfg' to
load the latest grub entry into the menu.

Reboot and select the new grub tboot menu entry!

## usage

Open up the script in your favorite editor and replace the following lines.

Place your own kernel version like 'uname -r' but for the lastest version
you want to boot.
So if you just updated using dnf to '4.11.12-200.fc25.x86_64' put that. Don't
use uname -r to get this value as it will only tell you the currently booted
version not the latest installed version.

```
latest_kernel="4.11.12-200.fc25.x86_64"
```

Replace the example kernel boot parameters EXACTLY as your own is.
You should have a file like /etc/grub.d/20_linux_tboot that is read by grub and
will place the extra needed kernel parameter "intel_iommu=on" at the end of your 
kernel line for the tboot grub entries. Remember to specify it here.

```
kernel_line="root=/dev/mapper/volgroup-rootvol ro rd.lvm.lv=volgroup/rootvol rd.luks.uuid=luks-6de17249-e365-4bc7-93e8-80e113d753c5 rd.lvm.lv=volgroup/swapvol rd.lvm.lv=volgroup/uservol rhgb quiet audit=1 intel_iommu=on"
```

Replace the example owner password with your own tpm owner password.

```
tpm_ownerpass="SoMeOTHerPaSSwoRD"
```

There are also options to specify tboot options and location.
I have set the default to log to display and memory, and the display
log to delay for 2 seconds on each screen(vga_delay=2), you may want to
remove this option for shorter boot time once everything is working.

```
tboot_options="logging=vga,memory vga_delay=2"
tboot_location="/boot/tboot.gz"
```

run the script and if the output looks ok reboot

```
$ ./tboot_update.sh
$ reboot
```

# troubleshooting

This document does not cover taking ownership of the tpm, make sure your tpm
is initalized before attempting to run this script.

run 'tpm_version' and make sure your version is 1.2

run 'tpm_selftest' and check the results are ok 00

'txt-stat' will give you information written to memory regions by tboot
(remember logging=vga,memory) and is probably the most useful and least talked
about tool for tpm diagnostics
