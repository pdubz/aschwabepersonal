#!/bin/bash -x

apt-get update
apt-get upgrade

# vmware tools
apt-get install binutils cpp gcc make psmisc linux-headers-$(uname -r)
mount /dev/cdrom /mnt
tar -C /tmp -zxvf /mnt/VMwareTools
umount /mnt
/tmp/vmware-tools-distrib/vmware-install.pl

apt-get install vim qterminal snapd curl telnet git
snap install code --classic

