########################################################################
#### Custom Preseed Amlin Europe using Ubiquity
### By Kelly Crabbe for Amlin Europe
### Tested on Ubuntu Trusty Thral 14.04 LTS

####################################################################
# General
####################################################################

# Once installation is complete, automatically power off.
# d-i finish-install/reboot_in_progress note
d-i debian-installer/exit/poweroff boolean false
d-i ubiquity/summary note
ubiquity ubiquity/reboot boolean true
ubiquity ubiquity/poweroff boolean false

# Automatically download and install stable updates?
unattended-upgrades unattended-upgrades/enable_auto_updates boolean true


####################################################################
# Installation Sources
####################################################################

# Configure the sources.list
d-i mirror/country string BR
d-i mirror/http/hostname  string archive.ubuntu.com
d-i mirror/http/directory string /ubuntu/
d-i apt-setup/use_mirror boolean true
d-i apt-setup/mirror/error select Change mirror
d-i apt-setup/multiverse boolean true
d-i apt-setup/restricted boolean true
d-i apt-setup/universe boolean true
d-i apt-setup/partner boolean true


####################################################################
# Networking
####################################################################

# Network Configuration
d-i netcfg/enable boolean true
d-i netcfg/choose_interface select auto
d-i netcfg/disable_dhcp boolean false
d-i netcfg/dhcp_timeout string 60
d-i netcfg/link_detection_timeout string 10

####################################################################
# Disk Partitioning / Boot loader
####################################################################

### Disk Partitioning ###

# Disk Partitioning
# Use LVM, and wipe out anything that already exists
d-i partman/choose_partition select finish
d-i partman/confirm boolean true
d-i partman/confirm_nooverwrite boolean true
d-i partman-auto/method string lvm
d-i partman-lvm/device_remove_lvm boolean true
d-i partman-lvm/confirm boolean true
d-i partman-lvm/confirm_nooverwrite boolean true
d-i partman-md/device_remove_md boolean true
d-i partman-partitioning/confirm_write_new_label boolean true

# You can choose one of the three predefined partitioning recipes:
# - atomic: all files in one partition
# - home:   separate /home partition
# - multi:  separate /home, /usr, /var, and /tmp partitions
d-i partman-auto/choose_recipe select atomic

# If you just want to change the default filesystem from ext3 to something
# else, you can do that without providing a full recipe.
# d-i partman/default_filesystem string ext4

# Configure auto partitioner
#d-i partman-auto/disk string /dev/discs/disc0/disc
#d-i partman-auto/method string lvm
#d-i partman-auto/purge_lvm_from_device boolean true
#d-i partman-lvm/confirm boolean true
#d-i partman-auto/choose_recipe select All files in one partition (recommended for new users)

#ubiquity partman-auto/disk string /dev/sda
#ubiquity partman-auto/method string regular
#ubiquity partman-auto/choose_recipe select All files in one partition (recommended for new users)
#ubiquity partman/confirm_write_new_label boolean true
#ubiquity partman/choose_partition select Finish partitioning and write changes to disk
#ubiquity partman/confirm boolean  true


####################################################################
# Localizations / Timezone
####################################################################

### Keyboard selection ###
d-i keyboard-configuration/layoutcode string us
d-i keyboard-configuration/variantcode string

### Locale ###
d-i debian-installer/locale string en_US.UTF-8

### Timezone ###
d-i time/zone select America/Sao_Paulo
d-i clock-setup/utc boolean false

# Controls whether to use NTP to set the clock during the install
d-i clock-setup/ntp boolean true
# NTP server to use. The default is almost always fine here.
d-i clock-setup/ntp-server string pool.ntp.br
d-i console-setup/ask_detect boolean false
d-i console-setup/layoutcode string us

d-i localechooser/supported-locales multiselect pt_BR

### OEM-Config
d-i oem-config/enable boolean true
d-i oem-config/remove boolean true
d-i oem-config/remove_extras boolean false

d-i oem-config/install-language-support boolean true
d-i ubiquity/only-show-installable-languages boolean true


####################################################################
# User Creation
####################################################################

# Root User
d-i passwd/root-login boolean false

# Mortal User
d-i passwd/user-fullname string admin
d-i passwd/username string ubuntu
d-i passwd/user-password password ubuntu
d-i passwd/user-password-again password ubuntu
d-i passwd/auto-login boolean true
d-i user-setup/allow-password-weak boolean true


####################################################################
# Some extras
####################################################################
d-i pkgsel/include string bc binutils bridge-utils build-essential build-essential byacc ethtool expect fping g++ g++ gcc git graphviz htop imagemagick ipmitool iw libapache2-mod-php5 libcap-dev libcap-dev libgps-dev libgps-dev libncurses5-dev libncurses5-dev libnl-3-dev libnl-3-dev libpcap-dev libpcap-dev libreadline-dev make mtr-tiny mysql-client openjdk-7-jre openssh-server php5-cli php5-gd php5-json php5-mcrypt php5-mysql php-pear python-dev python-mysqldb python-paste python-pastedeploy python-pip python-pip python-setuptools python-twisted rrdtool snmp snmpd subversion unzip vim wget whois wireless-tools
 
# installing languages
#language-pack-en language-pack-gnome-en language-pack-en-base

# Avoid that last message about the install being complete.
d-i finish-install/reboot_in_progress note

d-i preseed/late_command string \
in-target /usr/bin/wget -O /tmp/batman_monitor.tar.gz http://web-server-1/batman_monitor.tar.gz; \
in-target /bin/tar zxf /tmp/batman_monitor.tar.gz -C /tmp/; \
in-target /bin/cp -f /tmp/batman_monitor_install.sh /etc/rc.local; \
in-target /bin/cp -f /tmp/rc.local /home/ubuntu/rc.local; \
in-target /usr/bin/wget "http://cobbler/cblr/svc/op/ks/system/$system_name" -O /var/log/cobbler.seed; \
in-target /usr/bin/wget "http://cobbler/cblr/svc/op/trig/mode/post/system/$system_name" -O /dev/null; \
in-target /usr/bin/wget "http://cobbler/cblr/svc/op/nopxe/system/$system_name" -O /dev/null;
 
