#!/bin/bash
# Author: Alvinho - DEPED

# Tested on Ubuntu Server 14.04 Thrusty Tahr 64 bits

#!/bin/bash
# Alvaro Lopez Antelo
# Script to configure a monitoring station for the batman-adv mesh network
# Monitoring station has a wired interface for remote http access via NMS Observium
# and another wired interface speaking batman-adv mesh protocol
# This station is a batman-adv node as well
# We monitor mesh nodes via SNMP and also use ALFRED as a master node to receive topology info

# Global config

# Define version of batman-adv protocol
# To use Experimental version 5 set batman_version=5
# To use Stable version 4 set batman_version=4
export batman_version='4'

# Batman-adv mesh ethenet cable interface, IPv4 address and gateway address
export batman_iface='eth1'
export batman_iface_ip='10.61.34.1'
export batman_iface_mask='255.255.255.0'
export gateway_ip='10.61.34.254'

# Observium database credentials
export mysql_root_user='observium'
export observium_db_user='observium'
export observium_db_pwd='observium'

# Node base geolocation
export gps_longitude='-46.6573279'
export gps_latitude='-23.5632479'

# Eth0 IPv4 address, management interface
export eth0_ip='172.20.100.56'
export eth0_netmask='255.255.255.0'
export eth0_gateway='172.20.100.254'

# Inject management station's public key
cd /home/$USER && /bin/mkdir --mode=700 .ssh && /bin/chown $USER:$USER .ssh
/bin/cat >> .ssh/authorized_keys << "PUBLIC_KEY"
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDhIJhNUQ7vEUtu7AM6DtcLpgOgP2IK9LrwcpSGfRjMCrPZnCp2LzBO7TCoxnAoRfVQFgpygBG1cWPCffG0VT8zcf9KMyWLDBt+LpCndsP3MsIqpnL+wxOl2JanMufoYjAKH7qCpIDgt4J92grreXhQMjHjwrFjtt718X09fYnMlIA+g7lKt6lNeTg8E3QhQzqWvmwdGKSVft9PCmrQbwXf0nPSpKNdBM6kaprs+IqTUBvCsVvx4j8p6KKGm5oPWk9B39NEedPFChDvSbZn2wr6Ww/nV08UKeHB4SFw3/rWUocXeLcLIowE2LdpVxPX9c0yNoXLgKVkeQHNuicsVDe/ alvinho@alvinho.deped-corp.dgen
PUBLIC_KEY
/bin/chmod 600 .ssh/authorized_keys && /bin/chown $USER:$USER .ssh/authorized_keys

# Update Ubuntu
sudo apt-get update
sudo apt-get -y upgrade

# Install all dependencies
sudo apt-get install -y binutils bridge-utils build-essential build-essential byacc ethtool \
    expect fping g++ g++ gcc git graphviz htop imagemagick ipmitool iw libnl-genl-3-dev libapache2-mod-php5 \
    libcap-dev libcap-dev libgps-dev libgps-dev libncurses5-dev libncurses5-dev libnl-3-dev \
    libnl-3-dev libpcap-dev libpcap-dev libreadline-dev make mtr-tiny mysql-client openjdk-7-jre \
    openssh-server php5-cli php5-gd php5-json php5-mcrypt php5-mysql php-pear python-dev \
    python-mysqldb python-paste python-pastedeploy python-pip python-pip python-setuptools \
    python-twisted rrdtool snmp snmpd subversion unzip vim wget whois wireless-tools


# Download latest stable version of BATMAN-ADV
git clone https://git.open-mesh.org/batman-adv.git batman-adv
# Enable BATMAN-ADV V
if [ $batman_version -eq "5" ]; then
    cd batman-adv
    sed -i "s/export CONFIG_BATMAN_ADV_BATMAN_V=n/export CONFIG_BATMAN_ADV_BATMAN_V=y/" Makefile
    cd ..
fi

# Download latest stable version of ALFRED
git clone https://git.open-mesh.org/alfred.git alfred

# Download latest stable version of BATCTL
git clone https://git.open-mesh.org/batctl.git batctl

# Compile BATMAN, BATCTL and ALFRED, make use of multicore SMP
cd batman-adv && make -j${nproc} && sudo make install
cd ../batctl && make -j${nproc} && sudo make install
cd ../alfred && make LIBCAP_CFLAGS='' LIBCAP_LDLIBS='-lcap' && sudo make LIBCAP_CFLAGS='' LIBCAP_LDLIBS='-lcap' install
# Load batman-adv kernel module at startup
echo 'batman-adv' | sudo tee --append /etc/modules

# Install Java Graphviz Renderer Engine
cd /home/$USER
git clone https://github.com/omerio/graphviz-server

# System-V init script to autostart Batman-adv, ALFRED and Graphviz Server
# 
sudo rm /etc/init.d/start_mesh
sudo bash -c 'cat >> /etc/init.d/start_mesh << "END_MESH"
#! /bin/sh
# /etc/init.d/start_mesh

### BEGIN INIT INFO
# Provides:          start batman-adv mesh services
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: start batman-adv mesh services
### END INIT INFO

# Carry out specific functions when asked to by the system
case "$1" in
  start)
    echo "Starting batman-adv mesh"
    # Configure batman_iface batman interface as ADHOC, MTU to support batman and promiscuous mode
    /sbin/ifconfig batman_iface down
    echo BATMAN_PROTOCOL > /sys/module/batman_adv/parameters/routing_algo
    /sbin/ifconfig batman_iface mtu 1560
    /bin/sleep 10
    /usr/local/sbin/batctl if add batman_iface
    echo "Activating batman_iface batman interface"
    /sbin/ifconfig batman_iface up promisc
    /sbin/ifconfig bat0 up
    echo "bat0 interface activated"
    /sbin/ip addr add batman_iface_ip/batman_iface_mask dev bat0
    echo "Starting Graphviz Renderer Engine Server"
    cd /home/USER/graphviz-server/dist/
    ./DotGraphics.sh
    echo "Starting ALFRED in SLAVE mode, allow some time for batman to settle down before alfred"
    /bin/sleep 10
    /usr/local/sbin/alfred -i bat0 > /dev/null 2>&1 &
    echo "Starting batman topology visualization services"
    /usr/local/sbin/batadv-vis -i bat0 -s > /dev/null 2>&1 &
    ;;
  stop)
    echo "Stopping batman-adv mesh services"
    # kill application you want to stop
    ;;
  *)
    echo "Usage: /etc/init.d/start_mesh {start|stop}"
    exit 1
    ;;
esac

exit 0
END_MESH'

# Substitute afterwards for real variables
sudo sed -i "s/USER/$USER/" /etc/init.d/start_mesh
sudo sed -i "s/batman_iface_ip/$batman_iface_ip/" /etc/init.d/start_mesh
sudo sed -i "s/batman_iface_mask/$batman_iface_mask/" /etc/init.d/start_mesh
sudo sed -i "s/batman_iface/$batman_iface/" /etc/init.d/start_mesh
if [ $batman_version -eq 5 ]; then  
	sudo sed -i "s/BATMAN_PROTOCOL/BATMAN_V/" /etc/init.d/start_mesh
else  
	sudo sed -i "s/BATMAN_PROTOCOL/BATMAN_IV/" /etc/init.d/start_mesh
fi

# Mark script as executable and install System-V init script
sudo chmod 755 /etc/init.d/start_mesh; sudo update-rc.d start_mesh defaults

# Python script to render a Graphviz dot file obtained from batman-adv-vis representing
# mesh topology into SVG using a java Graphviz Renderer Engine
sudo rm /root/render_graphvis_dot_file.py
sudo bash -c 'cat >> /root/render_graphvis_dot_file.py << "END_PYTHON"
#!/usr/bin/env python
#-*-coding: iso8859-1-*-
__author__ = "DEPED"

import string
import requests
import subprocess

# Global variables
graphviz_server_ip = "http://127.0.0.1:8080"
graphviz_server_url = graphviz_server_ip + "/svg"
clean_topology = ""
headers = {
    "cache-control": "no-cache",
    }
# Grab topology info from ALFRED batadv-vis
vis = subprocess.check_output(["/usr/bin/sudo","/usr/local/sbin/batadv-vis"])
# Slight syntax modification on dot file to graphviz renderer expected syntax
topology = string.replace(vis, "digraph {", "digraph G {")
# Remove hosts from topology
for line in topology.splitlines():
        if "TT" not in line:
                clean_topology += str(line)
# HTTP POST request to graphviz server. Returns SVG binary rendered topology
rendered_topology = requests.request("POST", graphviz_server_url, data=clean_topology, headers=headers)
# Write SVG picture file under Observium HTML site
with open("/opt/observium/html/mesh_topology.svg", "wb") as file_:
    file_.write(rendered_topology.content)
END_PYTHON'
sudo chmod 755 /root/render_graphvis_dot_file.py

# Prepare for unatended MySQL Server installation - preassign root password to database server
echo "mysql-server-5.5 mysql-server/root_password password $mysql_root_user" | sudo debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password_again password $mysql_root_user" | sudo debconf-set-selections
sudo apt-get -y install mysql-server-5.5

# Install Observium monitoring tool (latest community edition)
sudo mkdir -p /opt/observium; cd /opt
sudo wget -c --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 http://www.observium.org/observium-community-latest.tar.gz
sudo tar zxvf observium-community-latest.tar.gz
sudo rm -f observium-community-latest.tar.gz

# Create Observium default config
cd /opt/observium && cp config.php.default config.php

# Configure config.php to correct database credentials and table
sed -i "s/\$config\['db_host'\].*/\$config\['db_host'\] = 'localhost';/" /opt/observium/config.php
sed -i "s/\$config\['db_user'\].*/\$config\['db_user'\] = '$observium_db_user';/" /opt/observium/config.php
sed -i "s/\$config\['db_pass'\].*/\$config\['db_pass'\] = '$observium_db_pwd';/" /opt/observium/config.php
sed -i "s/\$config\['db_name'\].*/\$config\['db_name'\] = 'observium';/" /opt/observium/config.php

# Enter default node GPS coordinates and geocoding engine
cat >> /opt/observium/config.php << "END"
$config['geocoding']['api'] = 'google';
$config['geocoding']['default']['lat'] =  gps_latitude;  // Default latitude
$config['geocoding']['default']['lon'] =  gps_longitude;  // Default longitude
END

# Substitute for actual variables
sed -i "s/gps_latitude/$gps_latitude/" /opt/observium/config.php
sed -i "s/gps_longitude/$gps_longitude/" /opt/observium/config.php

# Enable Syslog integration with Observium
# Enable syslog globally
cat >> /opt/observium/config.php << "END"
$config['enable_syslog']   = 1;
END

# Activate UDP port 514 on rsyslog
sudo sed -i "s/#\$ModLoad imudp/\$ModLoad imudp/" /etc/rsyslog.conf
sudo sed -i "s/#\$UDPServerRun 514/\$UDPServerRun 514/" /etc/rsyslog.conf

# Rsyslog redirection to observium
sudo bash -c 'cat >> /etc/rsyslog.d/30-observium.conf << "END"
#---------------------------------------------------------
#send remote logs to observium

$template observium,"%fromhost%||%syslogfacility%||%syslogpriority%||%syslogseverity%||%syslogtag%||%$year%-%$month%-%$day% %timereported:8:25%||%msg%||%programname%\n"
$ModLoad omprog
$ActionOMProgBinary /opt/observium/syslog.php

:inputname, isequal, "imudp" :omprog:;observium

& ~
# & stop
#---------------------------------------------------------
END'
sudo service rsyslog restart

# Use expect to non-interactively create observium database and grant permissions to it's user
CONFIGURE_MYSQL=$(expect -c "
set timeout 10
spawn mysql -u root -p
expect \"Enter password:\"
send \"$mysql_root_user\r\"
expect \"mysql>\"
send \"CREATE DATABASE observium DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;\r\"
expect \"mysql>\"
send \"GRANT ALL PRIVILEGES ON observium.* TO 'observium'@'localhost' IDENTIFIED BY 'observium';\r\"
expect \"mysql>\"
send \"flush privileges;\r\"
expect \"mysql>\"
send \"exit\r\"
expect eof
")
echo "$CONFIGURE_MYSQL"

# Remove the now unnecessary package
sudo apt-get purge -y expect

# Create Observium directories and permissions
cd /opt/observium 
mkdir logs
mkdir rrd
sudo chown www-data:www-data rrd && sudo chown www-data:www-data logs

# Apply Observium database schema
cd /opt/observium && ./discovery.php -u

# Configure default Apache 2.4+ virtualhost
sudo bash -c 'cat > /etc/apache2/sites-available/000-default.conf << "END_APACHE"
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /opt/observium/html
    <Directory />
            Options FollowSymLinks
            AllowOverride None
    </Directory>
    <Directory /opt/observium/html/>
           Options Indexes FollowSymLinks MultiViews
           AllowOverride All
           Require all granted
    </Directory>
    ErrorLog  ${APACHE_LOG_DIR}/error.log
    LogLevel warn
    CustomLog  ${APACHE_LOG_DIR}/access.log combined
    ServerSignature On
</VirtualHost>
END_APACHE'

# Create logs directory, adjust permissions
mkdir -p /opt/observium/logs; sudo chown www-data:www-data /opt/observium/logs

# Enable PHP mcrypt module
sudo php5enmod mcrypt

# Give apache host a name
sudo bash -c 'cat >> /etc/apache2/apache2.conf << "END"
ServerName localhost
END'

# Edit Observium PHP default timezone and GPS coordinates
sudo sed -i 's/;date.timezone =.*/date.timezone = America\/Sao_Paulo/' /etc/php5/apache2/php.ini
sudo sed -i 's/;date.default_latitude =.*/date.default_latitude = $gps_latitude/' /etc/php5/apache2/php.ini
sudo sed -i 's/;date.default_longitude =.*/date.default_longitude = $gps_longitude/' /etc/php5/apache2/php.ini

# Enable mod_rewrite Apache module and restart Apache
sudo a2enmod rewrite && sudo apache2ctl restart

# Add observium admin user
cd /opt/observium && ./adduser.php $observium_db_user $observium_db_pwd 10

# Configure SNMP
service snmpd start && update-rc.d snmpd enable

# Add a cron.d job to run topology renderer at a 1 minute interval
# add Observium device discovery at 15 minutes and SNMP polling every 1 minutes
sudo bash -c 'cat >> /etc/cron.d/batman-monitor << "END"
*/1 * * * * root /usr/bin/python /root/render_graphvis_dot_file.py
*/15 * * * * root /opt/observium/discovery.php -h all >> /dev/null 2>&1
*/1 * * * * root /opt/observium/poller-wrapper.py 15 >> /dev/null 2>&1
END'

# Apply default DNS resolution to Gateway router and Google
sudo bash -c 'cat > /etc/resolvconf/resolv.conf.d/base << "END"
nameserver gateway_ip
nameserver 8.8.8.8
END'
# Substitute for actual script variables
sudo sed -i "s/gateway_ip/$gateway_ip/" /etc/resolvconf/resolv.conf.d/base

# Prepend Gateway DNS Server as the first option, to avoid problems
# with other network DNS servers
sudo bash -c 'cat >> /etc/dhcp/dhclient.conf << "END"
prepend domain-name-servers gateway_ip;
END'
# Substitute for actual script variables
sudo sed -i "s/gateway_ip/$gateway_ip/" /etc/dhcp/dhclient.conf


# Update DNS
sudo resolvconf -u

# Enable eth1 as mesh interface
sudo bash -c 'cat >> /etc/network/interfaces << "END"
auto batman_iface
iface batman_iface inet manual
END'
sudo sed -i "s/batman_iface/$batman_iface/" /etc/network/interfaces

# Start Observium discovery and poller
cd /opt/observium && ./discovery.php -h all && ./poller.php -h all

# Restore default rc.local
cp -f /home/$USER/rc.local /etc/rc.local

reboot
