#!/bin/bash

###First uninstall any unnecessary packages and ensure that aptitude is installed.
apt-get update
apt-get -y install aptitude
aptitude -y install nano
/etc/init.d/apache2 stop
/etc/init.d/sendmail stop
/etc/init.d/bind9 stop
/etc/init.d/nscd stop
aptitude -y purge nscd bind9 sendmail apache2

###Uncomment to setup APT. Use ONLY if you're familiar with apt-pinning.
#echo ""
#echo "Setting up APT sources.list."
#./setup.sh apt

echo ""
echo "Setting up SSHD and Hostname."
./setup.sh basic
sleep 5

echo ""
echo "Installing LAMP stack."
./setup.sh lampworker
sleep 5

###Example for installing lampfpm
#echo "Installing LAMP stack."
#./setup.sh apt
#./setup.sh lampfpm
#sleep 5

echo ""
echo "Optimizing LAMP stack."
./setup.sh optimizelamp
sleep 5

echo ""
echo "Securing /tmp directory."
###Use tmpdd here if your server has under 256MB memory. Tmpdd will consume a 1GB disk space for /tmp
./setup.sh tmpfs

echo ""
echo "Installation complete!"
echo "Root login disabled."
echo "Please add a normal user now using the adduser command."