#!/bin/bash
###############################################################################################
# Complete LAMP setup script for Debian 5 and 6. For Debian 5, do not select lampfpm option   #
# LAMP stack is tuned for a 256MB VPS                                                         #
# First function is configurable                                                              #
# Email your questions to s@tuxlite.com                                                       #
###############################################################################################

source ./options.conf

###Functions Begin###

## error handling
error_out() {
# check if stderr is going to a terminal
if [[ -t 2 ]]; then
	# if it is a terminal, colorize output
	printf '\033[31;1m%s\033[0m\n' "ERROR: $@" >&2
else
	# if it is not a terminal, output plaintext
	printf '%s\n' "ERROR: $@" >&2
fi
} # end error_out() #


function add_new_user {

adduser $newuser

##Debian 5 users, do not touch below this line unless you know how to install Byobu from testing repo. 
##Uncomment to automatically attach to byobu session when user logs in
#echo "screen -x" > /home/$newuser/.bash_profile
#chown $newuser:$newuser /home/$newuser/.bash_profile

##Uncomment to configure byobu - automatically create windows and load programs on startup
#mkdir /home/$newuser/.byobu/
#touch /home/$newuser/.byobu/windows.startup

#cat > /home/$newuser/.byobu/windows.startup <<EOF
#screen -t root 0
#screen 1
#screen 2
#screen 3
#screen 4
#screen -t tor 5 rtorrent
#select 0
#EOF

#cp /home/$newuser/.byobu/{windows.startup,windows} 
#chown -R $newuser:$newuser /home/$newuser/.byobu

##Can also change byobu directory to load certain programs, e.g ventrilo
##chdir $HOME/ventsrv/
##screen -t vent 1 ./ventrilo_srv
##chdir $HOME
##screen -t teamspeak 2

#Uncomment to restart Byobu and load all programs again if the server gets rebooted
#sed -i '/exit/ i\su '${newuser}' -c "BYOBU_WINDOWS=startup byobu -dm"' /etc/rc.local

} #end function add_new_user


## check input/variables
check_variables() {
	# check sshd port to ensure it's numeric
	if [[ $sshd_port = *[!0-9]* || $sshd_port = 0* ]] || (( $sshd_port > 65536 )); then
		error_out "Please set sshd_port in options.conf to a numeric value between 1 and 65535."
		return 1
	fi
} # end function 'check_variables' #


function basic_server_setup {

#Reconfigure sshd - change port and disable root login
sed -i "s/^Port [0-9]*/Port $sshd_port/" /etc/ssh/sshd_config
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
/etc/init.d/ssh reload

# reconfigure /etc/adduser.conf to secure user's home directories on creation
sed -i 's/^DIR_MODE=[0-9]*/DIR_MODE=0750/' /etc/adduser.conf

#Set hostname and FQDN
sed -i 's/'${SERVER_IP}'.*/'${SERVER_IP}' '${HOSTNAME_FQDN}' '${HOSTNAME}'/' /etc/hosts
echo "$HOSTNAME" > /etc/hostname
/etc/init.d/hostname.sh start >/dev/null 2>&1

#Basic hardening of sysctl.conf
sed -i 's/^#net.ipv4.conf.all.accept_source_route = 0/net.ipv4.conf.all.accept_source_route = 0/' /etc/sysctl.conf
sed -i 's/^net.ipv4.conf.all.accept_source_route = 1/net.ipv4.conf.all.accept_source_route = 0/' /etc/sysctl.conf
sed -i 's/^#net.ipv6.conf.all.accept_source_route = 0/net.ipv6.conf.all.accept_source_route = 0/' /etc/sysctl.conf
sed -i 's/^net.ipv6.conf.all.accept_source_route = 1/net.ipv6.conf.all.accept_source_route = 0/' /etc/sysctl.conf

#Updates server and install commonly used utilities
aptitude update
aptitude -y safe-upgrade
aptitude -y install vim htop lynx dnsutils unzip byobu

} #end function basic_server_setup

### DELETE THIS CHUNK ###
function setup_apt {

#No longer necessary to use the line below for Debian 6 it seems...
#echo 'APT::Default-Release "stable";' >>/etc/apt/apt.conf

#Add Unstable, Testing repositories and configure pin priority to favor Stable packages
#Mainly to allow installation of php5-fpm package that is not in Stable repo

cp /etc/apt/{sources.list,sources.list.bak}
cat > /etc/apt/sources.list <<EOF
#Stable
deb http://ftp.$APT_REGION.debian.org/debian $RELEASE main non-free contrib
deb-src  http://ftp.$APT_REGION.debian.org/debian $RELEASE main non-free contrib

#Testing
deb http://ftp.$APT_REGION.debian.org/debian testing main non-free contrib
deb-src  http://ftp.$APT_REGION.debian.org/debian testing main non-free contrib

#Sid
deb http://ftp.$APT_REGION.debian.org/debian unstable main non-free contrib
deb-src  http://ftp.$APT_REGION.debian.org/debian unstable main non-free contrib

#Security
deb http://security.debian.org/ $RELEASE/updates main contrib non-free
deb-src http://security.debian.org/ $RELEASE/updates main contrib non-free
EOF

cat > /etc/apt/preferences <<EOF
Package: *
Pin: release a=$RELEASE
Pin-Priority: 700

Package: *
Pin: release a=testing
Pin-Priority: 650

Package: *
Pin: release a=unstable
Pin-Priority: 600
EOF

aptitude update

} #end function setup_apt

### DELETE CHUNK ###
function install_lamp {
#Install LAMP
aptitude -y install apache2 libapache2-mod-php5 php5-suhosin php-apc php5-mysql php5-dev php5-curl php5-gd php5-imagick php5-mcrypt php5-memcache php5-mhash php5-pspell php5-snmp php5-sqlite php5-xmlrpc php5-xsl
aptitude -y install awstats imagemagick

a2dismod php4
a2dismod fcgid
a2dismod fastcgi
a2dismod actions
a2enmod php5
a2enmod ssl
a2enmod rewrite

} #end function install_lamp

### USE THIS CHUNK ###
function install_lamp_fcgid {
#Install LAMP with mpm-worker and fastcgi, adapted from typo3's tutorial.
aptitude -y install libapache2-mod-fcgid apache2-mpm-worker php5-cgi php5-suhosin php-apc php5-mysql php5-dev php5-curl php5-gd php5-imagick php5-mcrypt php5-memcache php5-mhash php5-pspell php5-snmp php5-sqlite php5-xmlrpc php5-xsl apache2-suexec
aptitude -y install awstats imagemagick

a2dismod php4
a2dismod php5
a2dismod fastcgi
a2enmod actions
a2enmod fcgid
a2enmod ssl
a2enmod rewrite
a2enmod suexec

#Limit number of fcgi processes allowed and other fcgi settings. For a 512MB VPS, 5-10 is a good number. 
cat > /etc/apache2/mods-available/fcgid.conf <<EOF
#Original fcgid.conf contents
#<IfModule mod_fcgid.c>
#  AddHandler    fcgid-script .fcgi
#  FcgidConnectTimeout 20
#</IfModule>

<IfModule mod_fcgid.c>
	AddHandler fcgid-script .fcgi
	SocketPath /var/lib/apache2/fcgid/sock

	#Maximum number of PHP processes
	MaxProcessCount 5

	# Communication timeout (default: 20)
	IPCCommTimeout 60

	# Connection timeout (default: 3)
	#IPCConnectTimeout 3

	# Maximum request length (upload size) (default: 131072 (128KB))
	# Set to 10485760 (10MB)
	MaxRequestLen 10485760
</IfModule>
EOF

cat > /etc/apache2/conf.d/php-fcgid.conf <<EOF
<IfModule !mod_php4.c>
<IfModule !mod_php4_filter.c>
<IfModule !mod_php5.c>
<IfModule !mod_php5_filter.c>
<IfModule !mod_php5_hooks.c>
<IfModule mod_actions.c>
<IfModule mod_alias.c>
<IfModule mod_mime.c>
<IfModule mod_fcgid.c>
    #Path to php.ini . defaults to /etc/phpX/cgi
    DefaultInitEnv PHPRC=/etc/php5/cgi

    #Number of PHP childs that will be launched. Leave undefined to let PHP decide.
    #DefaultInitEnv PHP_FCGI_CHILDREN 3

    #Maximum requests before a process is stopped and a new one is launched
    DefaultInitEnv PHP_FCGI_MAX_REQUESTS 2000

    #Define a new handler "php-fcgi" for ".php" files, plus the action that must follow
    AddHandler php-fcgi .php
    Action php-fcgi /fcgi-bin/php-fcgi-wrapper

    #Define the MIME-Type for ".php" files
    AddType application/x-httpd-php .php

    #Define alias "/fcgi-bin/". The action above is using this value, which means that
    #you could run another "php5-cgi" command by just changing this alias
    Alias /fcgi-bin/ /srv/www/fcgi-bin.d/php5-default/

    #Turn on the fcgid-script handler for all files within the alias "/fcgi-bin/"
    <Location /fcgi-bin/>
        SetHandler fcgid-script
        Options +ExecCGI
    </Location>
</IfModule>
</IfModule>
</IfModule>
</IfModule>
</IfModule>
</IfModule>
</IfModule>
</IfModule>
</IfModule>
EOF

mkdir -p /var/www/fcgi-bin.d/php5-default
ln -s /usr/bin/php5-cgi /var/www/fcgi-bin.d/php5-default/php-fcgi-wrapper

} #end function install_lamp_fcgid


### DELETE CHUNK ###
function install_lamp_phpfpm {
#Install LAMP with mpm-worker and fastcgi and php-fpm
aptitude -y install libapache2-mod-fastcgi apache2-mpm-worker php5-cgi php5-suhosin php-apc php5-mysql php5-dev php5-curl php5-gd php5-imagick php5-mcrypt php5-memcache php5-mhash php5-pspell php5-snmp php5-sqlite php5-xmlrpc php5-xsl
aptitude -y install awstats imagemagick
aptitude install php5-fpm

a2dismod php4
a2dismod php5
a2dismod fcgid
a2enmod actions
a2enmod fastcgi
a2enmod ssl
a2enmod rewrite

#cp /etc/apache2/mods-available/{fastcgi.conf,fastcgi.conf.bak}
cat > /etc/apache2/mods-available/fastcgi.conf <<EOF
#Original fastcgi.conf contents
#<IfModule mod_fastcgi.c>
#  AddHandler fastcgi-script .fcgi
#  #FastCgiWrapper /usr/lib/apache2/suexec
#  FastCgiIpcDir /var/lib/apache2/fastcgi
#</IfModule>

<IfModule mod_fastcgi.c>
    FastCgiIpcDir /var/lib/apache2/fastcgi
    FastCGIExternalServer /srv/www/fcgi-bin.d/php5-fpm -flush -host 127.0.0.1:9000

    Alias /php5-fcgi /srv/www/fcgi-bin.d
    AddHandler php-fpm .php
    Action php-fpm /php5-fcgi/php5-fpm
    AddType application/x-httpd-php .php

    <Directory  "/srv/www/fcgi-bin.d">
    Order deny,allow
    Deny from all
        <Files "php5-fpm">
        Order allow,deny
        Allow from all
        </Files>
    </Directory>
</IfModule>
EOF

#Forms a symbolic link to the PHP5-FPM binary
mkdir -p /srv/www/fcgi-bin.d
ln -s /usr/sbin/php5-fpm  /srv/www/fcgi-bin.d/
/etc/init.d/php5-fpm restart

} #end function install_lamp_phpfpm


function install_mysql {
#Install mysql
echo "mysql-server-5.1 mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
echo "mysql-server-5.1 mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
aptitude -y install mysql-server mysql-client

echo -e "\033[35;1m Securing mysql and installing phpmyadmin - Please have your mysql root password at hand! \033[0m"
sleep 5

mysql_secure_installation
aptitude -y install phpmyadmin

} #end function install_mysql


function optimize_lamp {
#Removing Apache server information from headers. 
sed -i 's/ServerTokens .*/ServerTokens Prod/' /etc/apache2/conf.d/security
sed -i 's/ServerSignature .*/ServerSignature Off/' /etc/apache2/conf.d/security

#Add *:443 to ports.conf
temp=`grep "NameVirtualHost \*:443$" /etc/apache2/ports.conf | wc -l`
if [ $temp -lt 1 ]; then
sed -i '/\<IfModule mod_ssl.c\>/ a\    NameVirtualHost \*:443' /etc/apache2/ports.conf
fi

#Force phpmyadmin logins to be SSL secured
temp=`grep -i forcessl /etc/phpmyadmin/config.inc.php | wc -l`
if [ $temp -lt 1 ]; then
echo '$cfg['ForceSSL'] = 'true';' >> /etc/phpmyadmin/config.inc.php
fi

#Configure Awstats 
temp=`grep -i sitedomain /etc/awstats/awstats.conf.local | wc -l`
if [ $temp -lt 1 ]; then
echo SiteDomain="$HOSTNAME_FQDN" >> /etc/awstats/awstats.conf.local
fi
#Disable Awstats from executing every 10 minutes. Put a hash in front of any line.
sed -i 's/^[^#]/#&/' /etc/cron.d/awstats

#Debian 5 doesn't have buildstatic tool in the right directory.
DEB_VER=`cat /etc/debian_version`
DEB_VER=${DEB_VER:0:1}
if [ $DEB_VER -eq 5 ] && [ ! -d /usr/share/awstats/tools ]; then
mkdir /usr/share/awstats/tools
cp -R /usr/share/doc/awstats/examples/* /usr/share/awstats/tools
fi

#Change default log rotation for apache log files
sed -i 's/\tweekly/\tdaily/' /etc/logrotate.d/apache2
sed -i 's/\trotate .*/\trotate 10/' /etc/logrotate.d/apache2


#Tweak apache.conf, maxclients 45
cp /etc/apache2/{apache2.conf,apache2.conf.bak}
#sed -i 's/Timeout .*/Timeout 5/' /etc/apache2/apache2.conf
sed -i 's/\(^\s*StartServers\)\s*[0-9]*/\1         1/' /etc/apache2/apache2.conf
sed -i 's/\(^\s*MaxClients\)\s*[0-9]*/\1           45/' /etc/apache2/apache2.conf
sed -i 's/\(^\s*MinSpareThreads\)\s*[0-9]*/\1      2/' /etc/apache2/apache2.conf
sed -i 's/\(^\s*MaxSpareThreads\)\s*[0-9]*/\1      5/' /etc/apache2/apache2.conf
sed -i 's/\(^\s*ThreadLimit\)\s*[0-9]*/\1          15/' /etc/apache2/apache2.conf
sed -i 's/\(^\s*ThreadsPerChild\)\s*[0-9]*/\1      15/' /etc/apache2/apache2.conf
sed -i 's/\(^\s*MaxRequestsPerChild\)\s*[0-9]*/\1  2000/' /etc/apache2/apache2.conf


if [ -e "/etc/apache2/mods-enabled/fastcgi.conf" ]; then
php_ini_dir="/etc/php5/fpm/php.ini"
elif [ -e "/etc/apache2/mods-enabled/fcgid.conf" ]; then
php_ini_dir="/etc/php5/cgi/php.ini"
else
php_ini_dir="/etc/php5/apache2/php.ini"
fi

#Tweak php.ini, Execution time 2 mins, upload time 5mins, mem limit 64mb and upload file size 25MB.
sed -i 's/^\(max_execution_time = \)[0-9]*/\1120/' $php_ini_dir
sed -i 's/^\(max_input_time = \)[0-9]*/\1300/' $php_ini_dir
sed -i 's/^\(memory_limit = \)[0-9]*M/\164M/' $php_ini_dir
sed -i 's/^\(post_max_size = \)[0-9]*M/\125M/' $php_ini_dir
sed -i 's/^\(upload_max_filesize = \)[0-9]*M/\125M/' $php_ini_dir
sed -i 's/disable_functions =/disable_functions = exec,system,passthru,shell_exec,escapeshellarg,escapeshellcmd,proc_close,proc_open,dl,popen,show_source/' $php_ini_dir


if [ -e "/etc/apache2/mods-enabled/fastcgi.conf" ]; then
/etc/init.d/php5-fpm restart
fi

#Generating self signed SSL certs for securing phpmyadmin, script logins
echo -e " "
echo -e "\033[35;1m Generating SSL certs, you do not have to enter any details when asked. But recommended to enter Hostname FQDN for 'Common Name'! \033[0m"
mkdir /etc/ssl/localcerts
openssl req -new -x509 -days 365 -nodes -out /etc/ssl/localcerts/apache.pem\
 -keyout /etc/ssl/localcerts/apache.key

#Tweak my.cnf
cp /etc/mysql/{my.cnf,my.cnf.bak}
if [ -e /usr/share/doc/mysql-server-5.1/examples/my-medium.cnf.gz ]; then
gunzip /usr/share/doc/mysql-server-5.1/examples/my-medium.cnf.gz
cp /usr/share/doc/mysql-server-5.1/examples/my-medium.cnf /etc/mysql/my.cnf
else
gunzip /usr/share/doc/mysql-server-5.0/examples/my-medium.cnf.gz
cp /usr/share/doc/mysql-server-5.0/examples/my-medium.cnf /etc/mysql/my.cnf
fi
sed -i '/myisam_sort_buffer_size/ a\skip-innodb' /etc/mysql/my.cnf
/etc/init.d/mysql restart
} #end function optimize_lamp


function install_postfix {

#Install postfix
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
echo "postfix postfix/mailname string $HOSTNAME_FQDN" | debconf-set-selections
echo "postfix postfix/destinations string localhost.localdomain, localhost" | debconf-set-selections
aptitude -y install postfix

#Allow mail delivery from localhost only
/usr/sbin/postconf -e "inet_interfaces = loopback-only"

sleep 1
postfix stop
sleep 1
postfix start

} #end function install_postfix


function install_rtorrent {

aptitude -y install rtorrent

cp /usr/share/doc/rtorrent/examples/rtorrent.rc /home/$torrentuser/.rtorrent.rc
mkdir /home/$torrentuser/watch
chown $torrentuser:$torrentuser /home/$torrentuser/.rtorrent.rc
chown $torrentuser:$torrentuser /home/$torrentuser/watch

sed -i 's/\#max_peers =.*/max_peers = 100/' /home/$torrentuser/.rtorrent.rc
sed -i 's/\#max_uploads =.*/max_uploads = 25/' /home/$torrentuser/.rtorrent.rc
sed -i 's/\#download_rate =.*/download_rate = 2000/' /home/$torrentuser/.rtorrent.rc
sed -i 's/\#upload_rate =.*/upload_rate = 1000/' /home/$torrentuser/.rtorrent.rc
sed -i 's/\#schedule = watch_directory,5,5,load_start=\.\/watch\/\*\.torrent/schedule = watch_directory,5,5,load_start=.\/watch\/\*.torrent/' /home/$torrentuser/.rtorrent.rc
sed -i 's/\#schedule = untied_directory,5,5,stop_untied=/schedule = untied_directory,5,5,stop_untied=/' /home/$torrentuser/.rtorrent.rc
sed -i 's/\#schedule = low_diskspace,5,60,close_low_diskspace=100M/schedule = low_diskspace,5,60,close_low_diskspace=100M/' /home/$torrentuser/.rtorrent.rc
sed -i '/\#schedule = ratio/ a\ratio.enable=1\nratio.min.set=200;\nratio.max.set=500;\nratio.upload.set=200M; ' /home/$torrentuser/.rtorrent.rc
sed -i 's/\#port_range =.*/port_range = 40000-45000/' /home/$torrentuser/.rtorrent.rc


} #end function install_rtorrent


function check_tmp_secured {

temp1=`grep -w "/var/tempFS /tmp ext3 loop,nosuid,noexec,rw 0 0" /etc/fstab | wc -l`
temp2=`grep -w "tmpfs /tmp tmpfs rw,noexec,nosuid 0 0" /etc/fstab | wc -l`

if [ $temp1  -gt 0 ] || [ $temp2 -gt 0 ]; then
return 1
else 
return 0
fi

}


function secure_tmp_tmpfs {

cp /etc/fstab /etc/fstab.bak
#Backup /tmp
cp -Rpf /tmp /tmpbackup

rm -rf /tmp
mkdir /tmp

mount -t tmpfs -o rw,noexec,nosuid tmpfs /tmp
chmod 1777 /tmp
echo "tmpfs /tmp tmpfs rw,noexec,nosuid 0 0" >> /etc/fstab

#Restore /tmp
cp -Rpf /tmpbackup/* /tmp/ >/dev/null 2>&1

#Remove old tmp dir
rm -rf /tmpbackup

#Backup /var/tmp and link it to /tmp
mv /var/tmp /var/tmpbackup
ln -s /tmp /var/tmp

#Copy the old data back
cp -Rpf /var/tmpold/* /tmp/ >/dev/null 2>&1
#Remove old tmp dir
rm -rf /var/tmpbackup
}


function secure_tmp_dd {

cp /etc/fstab /etc/fstab.bak

#Create 1GB space for /tmp, change count if you want smaller/larger size
dd if=/dev/zero of=/var/tempFS bs=1024 count=$TMP_SIZE
#Make space as a ext3 filesystem
/sbin/mkfs.ext3 /var/tempFS

#Backup /tmp
cp -Rpf /tmp /tmpbackup

#Secure /tmp 
mount -o loop,noexec,nosuid,rw /var/tempFS /tmp
chmod 1777 /tmp
echo "/var/tempFS /tmp ext3 loop,nosuid,noexec,rw 0 0" >> /etc/fstab

#Restore /tmp
cp -Rpf /tmpbackup/* /tmp/ >/dev/null 2>&1

#Remove old tmp dir
rm -rf /tmpbackup

#Backup /var/tmp and link it to /tmp
mv /var/tmp /var/tmpbackup
ln -s /tmp /var/tmp

#Copy the old data back
cp -Rpf /var/tmpold/* /tmp/ >/dev/null 2>&1
#Remove old tmp dir
rm -rf /var/tmpbackup
}


function varnish_on {

aptitude -y install varnish libapache2-mod-rpaf

#Configure varnish
tmp=`grep -i "start=" /etc/default/varnish | wc -l`
if [ $tmp -lt 1 ]; then
sed -i '1iSTART=no' /etc/default/varnish
fi
sed -i 's/START=no/START=yes/' /etc/default/varnish
sed -i 's/^\s*DAEMON_OPTS="-a :6081/DAEMON_OPTS="-a \*:80/' /etc/default/varnish
sed -i 's/\(^\s*-s\) [^ ][^ ]*./\1 malloc,'${VARNISH_CACHE_SIZE}'"/' /etc/default/varnish

#Change apache and virtualhost ports to 8080
sed -i 's/:80$/:8080/' /etc/apache2/ports.conf
sed -i 's/Listen 80$/Listen 8080/' /etc/apache2/ports.conf
sed -i 's/:80>$/:8080>/' /etc/apache2/sites-available/*

apache2ctl restart
sleep 3
/etc/init.d/varnish start
}


function varnish_off {

#Revert apache and virtualhost ports to 80
sed -i 's/:8080$/:80/' /etc/apache2/ports.conf
sed -i 's/Listen 8080/Listen 80/' /etc/apache2/ports.conf
sed -i 's/:8080>$/:80>/' /etc/apache2/sites-available/*

#Stops varnish from starting
sed -i 's/START=yes/START=no/' /etc/default/varnish

/etc/init.d/varnish stop
sleep 3
apache2ctl restart

}


####Main program begins####
#Show Menu#
if [ ! -n "$1" ]; then
    echo ""
    echo -e  "\033[35;1mIMPORTANT!! Edit Options.conf before executing\033[0m"
    echo -e  "\033[35;1mA standard install would be - basic + add + lampworker + optimizelamp + tmpfs\033[0m"
    echo ""
    echo -e  "\033[35;1mSelect from the options below to use this script:- \033[0m"
    echo -n  "$0"
    echo -ne "\033[36m basic\033[0m"
    echo     " - Disable root SSH logins, change SSH port, set hostname, installs vim htop lynx dnsutils unzip byobu."

    echo -n  "$0"
    echo -ne "\033[36m add USERNAME\033[0m"
    echo     " - Add new user and setup bash_profile to auto attach byobu sessions. Configurable function - by default only adds user and does nothing else."

    echo -n "$0"
    echo -ne "\033[36m apt\033[0m"
    echo     " - Add Unstable and Testing repositories. Configure pin priority to favor Stable packages. Do not use except to install PHP-FPM."

    echo -n "$0"
    echo -ne "\033[36m lamp\033[0m"
    echo     " - Installs LAMP stack using mpm-prefork and mod_php. Also installs Awstats, Phpmyadmin and Postfix."

    echo -n "$0"
    echo -ne "\033[36m lampworker\033[0m"
    echo     " - [RECOMMENDED] Installs LAMP stack using mpm-worker, mod-fcgid. Also installs Awstats, Phpmyadmin and Postfix."

    echo -n "$0"
    echo -ne "\033[36m lampfpm\033[0m"
    echo     " - Similar to above but uses mod_fastcgi and PHP-FPM from Unstable repo. Not recommended for production sites. Use script to add Unstable repositories before executing!"

    echo -n "$0"
    echo -ne "\033[36m optimizelamp\033[0m"
    echo     " - Optimizes apache2.conf, php.ini and my.cnf. Also generates self signed SSL certs."

    echo -n "$0"
    echo -ne "\033[36m rtorrent USERNAME\033[0m"
    echo     " - Installs and configures rtorrent to USERNAME's home directory. Watch directory is also added for automated torrent downloads."

    echo -n "$0"
    echo -ne "\033[36m tmpfs\033[0m"
    echo     " - Secures /tmp and /var/tmp using tmpfs. Not recommended for servers with less than 512MB dedicated RAM."

    echo -n "$0"
    echo -ne "\033[36m tmpdd\033[0m"
    echo     " - Secures /tmp and /var/tmp using a file created on disk. Tmp size is 1GB."

    echo -n "$0"
    echo -ne "\033[36m varnish on|off\033[0m"
    echo     " - Starts/Stops Varnish. Set cache size in options.conf. Changes/Reverts Nginx virtualhosts to port 8080/80."

    echo ""
    exit
fi
#End Show Menu#



#Start execute functions#
case $1 in
apt)
    setup_apt
    echo -e "\033[35;1m Unstable and Testing repo added to /etc/apt/sources.list\033[0m"
  ;;
add)
    if [ $# -eq 2 ]; then
        newuser=$2
        add_new_user
    else
        echo -e "\033[35;1m Please enter a username! \033[0m"
    exit 0;
    fi
  ;;
basic)
	check_variables || exit
	basic_server_setup
	echo -e "\033[35;1m Root login disabled, SSH port set to $sshd_port. Hostname set to $HOSTNAME and FQDN to $HOSTNAME_FQDN. \033[0m"
	echo -e "\033[35;1m Htop, lynx, dnsutils, unzip, byobu installed. \033[0m"
	echo -e "\033[35;1m Remember to create a normal user account for login or you will be locked out from your box! \033[0m"
;; # end case 'basic' #
lamp)
    install_lamp
    install_mysql
    install_postfix
    apache2ctl restart
    sleep 2
    apache2ctl restart
    echo -e "\033[35;1m Apache2 MPM-Prefork + MySQL + Mod_PHP installation complete! Enjoy! \033[0m"
  ;;
lampworker)
    install_lamp_fcgid
    install_mysql
    install_postfix
    apache2ctl restart
    sleep 2
    apache2ctl restart
    echo -e "\033[35;1m Apache2 MPM-Worker + MySQL + PHP-CGI installation complete! Enjoy! \033[0m"
  ;;
lampfpm)
    install_lamp_phpfpm
    install_mysql
    install_postfix
    apache2ctl restart
    sleep 2
    apache2ctl restart

    if [ -e "/etc/php5/fpm/php.ini" ]; then
        echo -e "\033[35;1m Apache2 MPM-Worker + MySQL + PHP-FPM installation complete! Enjoy! \033[0m"
    else
        echo -e "\033[35;1m Install failed! Try running script with 'apt' switch to add Unstable repos before trying again. \033[0m"
        echo -e "\033[35;1m Also make sure to select correct dependency solution when prompted during PHP-FPM installation. \033[0m"
    fi
  ;;
optimizelamp)
    optimize_lamp
    sleep 2
    apache2ctl restart
    echo -e "\033[35;1m Optimize complete! \033[0m"
  ;;
rtorrent)
    if [ $# -eq 2 ]; then
        torrentuser=$2
    else
        echo -e "\033[35;1m Please enter a username! \033[0m"
        exit 0;
    fi

    if [ -d "/home/$torrentuser" ];then
        install_rtorrent
        echo -e "\033[35;1m rtorrent installed! Enjoy! \033[0m"
        echo -e "\033[35;1m A 'watch' folder has been created in the user's home directory. Torrent files in there will start downloading automatically. \033[0m"
        echo -e "\033[35;1m Client configured to seed to a ratio of 2.0. Settings stored in /home/$2/.rtorrent.rc \033[0m"
    else
        echo -e "\033[35;1m User doesn't exist! \033[0m"
    fi
  ;;
tmpdd)
    check_tmp_secured
    if [ $? = 0  ]; then
        secure_tmp_dd
        echo -e "\033[35;1m /tmp and /var/tmp secured using file created using dd. \033[0m"
    else
        echo -e "\033[35;1mFunction canceled. /tmp already secured. \033[0m"
	fi
  ;;
tmpfs)
	check_tmp_secured
    if [ $? = 0  ]; then
	    secure_tmp_tmpfs
        echo -e "\033[35;1m /tmp and /var/tmp secured using tmpfs. \033[0m"
    else
        echo -e "\033[35;1mFunction canceled. /tmp already secured. \033[0m"
	fi
  ;;
varnish)
    if [ "$2" = "on" ]; then
        varnish_on
        echo -e "\033[35;1m Varnish now enabled. \033[0m"
    elif [ "$2" = "off" ]; then
        varnish_off
        echo -e "\033[35;1m Varnish disabled. \033[0m"
    fi
  ;;
esac
#End execute functions#
