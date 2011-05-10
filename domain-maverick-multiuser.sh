#!/bin/bash
##############################################################
# Complete Virtualhost setup script for TuxLite Scripts      #
# Quickly add or remove virtualhost domains                  #
##############################################################

#Enable or disable AWStats. Option = yes|no
AWSTATS_ENABLE="yes"

#Check domain to see if it contains invalid characters. Option = yes|no.
CHECK_VALIDITY="yes"

#### First initialize some variables ####

## Set who owns the domain. For suexec setup, variable is overwritten
DOMAIN_OWNER="www-data"

## Specify where phpmyadmin is
## /usr/local/share for self installed phpmyadmin
## /usr/share for PMA installed via package manager
PHPMYADMIN_PATH="/usr/share/phpmyadmin/"

## Logrotate Postrotate for Nginx
#POSTROTATE_CMD='[ ! -f /var/run/nginx.pid ] || kill -USR1 `cat /var/run/nginx.pid`'
## Logrotate Postrotate for Apache
POSTROTATE_CMD='/etc/init.d/apache2 reload > /dev/null'

## Variables for awstats/phpmyadmin functions
## The path to find for PMA and Awstats symbolic links
FIND_PATH="/home/*/domains/*/public_html"
VHOST_ROOT="/home/*/domains/*"

#Default PHP-FPM socket path
PHP_FPM_SOCKET_PATH="/var/run"

### Functions Begin ###

function initialize_variables {

DOMAIN_PATH="/home/$DOMAIN_OWNER/domains/$DOMAIN"
DOMAIN_CONFIG_PATH="/etc/apache2/sites-available/$DOMAIN"
DOMAIN_ENABLED_PATH="/etc/apache2/sites-enabled/$DOMAIN"
#Awstats command to be placed in logrotate file
if [ $AWSTATS_ENABLE = 'yes' ]; then
    AWSTATS_CMD="/usr/share/awstats/tools/awstats_buildstaticpages.pl -update -config=$DOMAIN -dir=$DOMAIN_PATH/awstats -awstatsprog=/usr/lib/cgi-bin/awstats.pl > /dev/null"
else
    AWSTATS_CMD=""
fi
#Name of the logrotate file
LOGROTATE_FILE="domain-$DOMAIN"

}

function reload_webserver {

#/etc/init.d/nginx reload
## For Ubuntu systems
#service nginx reload

apache2ctl graceful

}

function php_fpm_add_user {

#Copy over FPM template if it doesn't exist
if [ ! -e /etc/php5/fpm/pool.d/$DOMAIN_OWNER.conf ]; then
    cp /etc/php5/fpm/pool.d/{www.conf,$DOMAIN_OWNER.conf}
fi

#Change pool user, group and socket
sed -i  's/^\[www\]$/\['${DOMAIN_OWNER}'\]/' /etc/php5/fpm/pool.d/$DOMAIN_OWNER.conf
sed -i 's/^listen =.*/listen = \/var\/run\/php5-fpm-'${DOMAIN_OWNER}'.sock/' /etc/php5/fpm/pool.d/$DOMAIN_OWNER.conf
sed -i 's/^user = www-data$/user = '${DOMAIN_OWNER}'/' /etc/php5/fpm/pool.d/$DOMAIN_OWNER.conf
sed -i 's/^group = www-data$/group = '${DOMAIN_OWNER}'/' /etc/php5/fpm/pool.d/$DOMAIN_OWNER.conf

service php5-fpm restart

}

function add_domain {

#Create public_html and log directories for domain
mkdir -p $DOMAIN_PATH/{logs,public_html}

cat > $DOMAIN_PATH/public_html/robots.txt <<EOF
User-agent: *
Disallow: /stats/
EOF

cat > $DOMAIN_PATH/public_html/index.html <<EOF
Welcome to the default placeholder!
Overwrite or remove index.html when uploading your site.
EOF

#Setup awstats directories
if [ $AWSTATS_ENABLE = 'yes' ]; then
    mkdir -p $DOMAIN_PATH/{awstats,awstats/.data}
    cd $DOMAIN_PATH/awstats/
    ln -s awstats.$DOMAIN.html index.html
    ln -s /usr/share/awstats/icon awstats-icon
    cd - &> /dev/null
    ln -s ../awstats $DOMAIN_PATH/public_html/stats
fi

#Set permissions
chown -R $DOMAIN_OWNER:$DOMAIN_OWNER $DOMAIN_PATH
chmod 711 /home/$DOMAIN_OWNER/domains
chmod 711 $DOMAIN_PATH

#Virtualhost entry
cat > $DOMAIN_CONFIG_PATH <<EOF
<VirtualHost *:80>

    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    ServerAdmin admin@$DOMAIN
    DocumentRoot $DOMAIN_PATH/public_html/
    ErrorLog $DOMAIN_PATH/logs/error.log
    CustomLog $DOMAIN_PATH/logs/access.log combined

    FastCGIExternalServer $DOMAIN_PATH/public_html/php5-fpm -pass-header Authorization -socket $PHP_FPM_SOCKET_PATH/php5-fpm-$DOMAIN_OWNER.sock
    Alias /php5-fcgi $DOMAIN_PATH/public_html

    <Directory $DOMAIN_PATH/public_html>
    	Options Indexes FollowSymLinks
    	AllowOverride All
    	Order allow,deny
    	allow from all
    </Directory>

    ScriptAlias /cgi-bin/ /usr/lib/cgi-bin/
    <Location /cgi-bin>
        Options +ExecCGI
    </Location>

</VirtualHost>


<IfModule mod_ssl.c>
<VirtualHost *:443>

    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    ServerAdmin admin@$DOMAIN
    DocumentRoot $DOMAIN_PATH/public_html/
    ErrorLog $DOMAIN_PATH/logs/error.log
    CustomLog $DOMAIN_PATH/logs/access.log combined

    Alias /php5-fcgi $DOMAIN_PATH/public_html

    <Directory $DOMAIN_PATH/public_html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Order allow,deny
        allow from all
    </Directory>

    ScriptAlias /cgi-bin/ /usr/lib/cgi-bin/
    <Location /cgi-bin>
        Options +ExecCGI
    </Location>

    SSLEngine on
    SSLCertificateFile    /etc/ssl/localcerts/apache.pem
    SSLCertificateKeyFile /etc/ssl/localcerts/apache.key

    <FilesMatch "\.(cgi|shtml|phtml|php)$">
        SSLOptions +StdEnvVars
    </FilesMatch>

    <Directory /usr/lib/cgi-bin>
        SSLOptions +StdEnvVars
    </Directory>

    BrowserMatch "MSIE [2-6]" nokeepalive ssl-unclean-shutdown downgrade-1.0 force-response-1.0
    BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown

</VirtualHost>
</IfModule>
EOF


#Configure Awstats for domain
cp /etc/awstats/awstats.conf /etc/awstats/awstats.$DOMAIN.conf
sed -i 's/^SiteDomain=.*/SiteDomain="'${DOMAIN}'"/' /etc/awstats/awstats.$DOMAIN.conf
sed -i 's/^LogFile=.*/\#Deleted LogFile parameter. Appended at the bottom of this config file instead./' /etc/awstats/awstats.$DOMAIN.conf
sed -i 's/^LogFormat=.*/LogFormat=1/' /etc/awstats/awstats.$DOMAIN.conf
sed -i 's/^DirData=.*/\#Deleted DirData parameter. Appended at the bottom of this config file instead./' /etc/awstats/awstats.$DOMAIN.conf
sed -i 's/^DirIcons=.*/DirIcons=".\/awstats-icon"/' /etc/awstats/awstats.$DOMAIN.conf
sed -i '/Include \"\/etc\/awstats\/awstats\.conf\.local\"/ d' /etc/awstats/awstats.$DOMAIN.conf
echo "LogFile=\"$DOMAIN_PATH/logs/access.log\"" >> /etc/awstats/awstats.$DOMAIN.conf
echo "DirData=\"$DOMAIN_PATH/awstats/.data\"" >> /etc/awstats/awstats.$DOMAIN.conf

#Add new logrotate entry for domain
cat > /etc/logrotate.d/$LOGROTATE_FILE <<EOF
$DOMAIN_PATH/logs/*.log {
	daily
	missingok
	rotate 10
	compress
	delaycompress
	notifempty
	create 0640 $DOMAIN_OWNER adm
	sharedscripts
	prerotate
		$AWSTATS_CMD
	endscript
	postrotate
		$POSTROTATE_CMD
	endscript
}
EOF

ln -s $DOMAIN_CONFIG_PATH $DOMAIN_ENABLED_PATH
} #end of add_domain function


function remove_domain {

#First disable domain and reload webserver
echo "Disabling $DOMAIN_ENABLED_PATH"
rm -rf $DOMAIN_ENABLED_PATH
reload_webserver
#Then delete all files and config files
echo "Removing /etc/awstats/awstats.$DOMAIN.conf"
rm -rf /etc/awstats/awstats.$DOMAIN.conf
echo "Removing $DOMAIN_PATH"
rm -rf $DOMAIN_PATH
echo "Removing $DOMAIN_CONFIG_PATH"
rm -rf $DOMAIN_CONFIG_PATH
echo "Removing /etc/logrotate.d/$LOGROTATE_FILE"
rm -rf /etc/logrotate.d/$LOGROTATE_FILE

} #end of remove_domain function


function check_domain_exists {

if [ -e "$DOMAIN_CONFIG_PATH" ] || [ -e "$DOMAIN_PATH" ]; then
	return 0
	else
	return 1
fi

} #end of check_domain_exists function


function check_domain_valid {

if [ "$CHECK_VALIDITY" = "yes" ]; then
    if [[ "$DOMAIN" =~ [\~\!\@\#\$\%\^\&\*\(\)\_\+\=\{\}\|\\\;\:\'\"\<\>\?\,\/\[\]] ]]; then
        echo -e "\033[35;1mERROR: Domain check failed. Please enter a valid domain.\033[0m"
        echo -e "\033[35;1mERROR: If you are certain this domain is valid, then disable domain checking option at the beginning of the script.\033[0m"
        return 1
    else
        return 0
    fi
else
#Check_validity variable is set to "NO"
    return 0
fi
} #end of check_domain_valid function


function awstats_off {

#Search virtualhost directory to look for "stats" symbolic links
test=`find $FIND_PATH -maxdepth 1 -name "stats" -type l -print0 | xargs -0 -I path echo path > /tmp/awstats.txt`

#Remove symbolic links
while read LINE; do
    rm -rfv $LINE
done < "/tmp/awstats.txt"
rm -rf /tmp/awstats.txt

echo -e "\033[35;1mAwstats disabled. If you do not see any \"removed\" messages, it means it has already been disabled.\033[0m"

} #end of awstats_off


function awstats_on {

#Search virtualhost directory to look for "stats". In case the user created a stats folder, we do not want to overwrite it.
test=`find $FIND_PATH -maxdepth 1 -name "stats" -print0 | xargs -0 -I path echo path | wc -l`
if [ $test -eq 0 ]; then
    find $VHOST_ROOT -maxdepth 1 -name "public_html" -type d | xargs -L1 -I path ln -sv ../awstats path/stats
    echo -e "\033[35;1mAwstats enabled.\033[0m"
else
    echo -e "\033[35;1mERROR: Failed to enable Awstats for all domains. Exiting... \033[0m"
    echo -e "\033[35;1mERROR: Awstats is already enabled for at least 1 domain. \033[0m"
    echo -e "\033[35;1mERROR: Turn Awstats off again before re-enabling. \033[0m"
    echo -e "\033[35;1mERROR: Also ensure that all your public_html do not have a manually created \"stats\" folder. \033[0m"
fi

} #end of awstats_on


function phpmyadmin_off {

#Search virtualhost directory to look for "p" symbolic links
test=`find $FIND_PATH -maxdepth 1 -name "p" -type l -print0 | xargs -0 -I path echo path > /tmp/phpmyadmin.txt`
#Remove symbolic links
while read LINE; do
    rm -rfv $LINE
done < "/tmp/phpmyadmin.txt"
rm -rf /tmp/phpmyadmin.txt

echo -e "\033[35;1mPhpmyadmin disabled. If you do not see any \"removed\" messages, it means it has already been disabled.\033[0m"

} #end of phpmyadmin_off


function phpmyadmin_on {

#Search virtualhost directory to look for "p". In case the user created a "p" folder, we do not want to overwrite it.
test=`find $FIND_PATH -maxdepth 1 -name "p" -print0 | xargs -0 -I path echo path | wc -l`
if [ $test -eq 0 ]; then
    find $VHOST_ROOT -maxdepth 1 -name "public_html" -type d | xargs -L1 -I path ln -sv $PHPMYADMIN_PATH path/p
    echo -e "\033[35;1mPhpmyadmin enabled.\033[0m"
else
    echo -e "\033[35;1mERROR: Failed to enable Phpmyadmin for all domains. Exiting... \033[0m"
    echo -e "\033[35;1mERROR: Phpmyadmin is already enabled for at least 1 domain. \033[0m"
    echo -e "\033[35;1mERROR: Turn Phpmyadmin off again before re-enabling. \033[0m"
    echo -e "\033[35;1mERROR: Also ensure that all your public_html do not have a manually created \"p\" folder. \033[0m"
fi

} #end of phpmyadmin_on


####Main program begins####

if [ ! -n "$1" ]; then
    echo ""
    echo -e "\033[35;1mSelect from the options below to use this script:- \033[0m"
    echo -n  "$0"
    echo -ne "\033[36m add user Domain.tld\033[0m"
    echo     " - Add specified domain to \"user's\" home directory. Awstats and log rotation will be configured."

    echo -n  "$0"
    echo -ne "\033[36m remove user Domain.tld\033[0m"
    echo     " - Remove everything for Domain.tld including stats and public_html. If necessary, backup domain files before executing!"

    echo -n  "$0"
    echo -ne "\033[36m awstats on|off\033[0m"
    echo     " - Disable or enable public viewing of Awstats. Stats data is preserved."

    echo -n  "$0"
    echo -ne "\033[36m pma on|off\033[0m"
    echo     " - Disable or enable public viewing of Phpmyadmin. Only enable when you need to use it to prevent brute force attacks."

    echo ""
    exit
fi

#Start execute functions#
case $1 in
add)
	if [ $# -ne 3 ]; then
	    echo "Please enter all the required parameters."
		exit
	fi

    DOMAIN_OWNER=$2
    DOMAIN=$3
    initialize_variables

    if [ ! -d /home/$DOMAIN_OWNER ]; then
	    echo "Please enter a valid user."
		exit 
	fi

    check_domain_valid
    if [ $? -ne 0 ]; then
        exit 1
	fi

	check_domain_exists
	if [  $? -eq 0  ]; then
	    echo -e "\033[35;1m$DOMAIN_CONFIG_PATH already exists, please remove the existing domain first before adding it again. \033[0m" 
		exit
	else
		add_domain
        php_fpm_add_user
        reload_webserver
		echo -e "\033[35;1mDomain $DOMAIN added. \033[0m"
		echo -e "\033[35;1mYou can now upload your site to $DOMAIN_PATH/public_html. \033[0m"
		echo -e "\033[35;1mPhpmyadmin is DISABLED by default. PMA URL = http://$DOMAIN/p.\033[0m"
		echo -e "\033[35;1mAWStats URL = http://$DOMAIN/stats. \033[0m"
		echo -e "\033[35;1mStats updates daily. Allow 24H before viewing stats or you will be greeted with an error page. \033[0m"
        echo -e "\033[35;1mIf Varnish cache is enabled, please disable & enable it again to reconfigure this domain. \033[0m"
	fi
  ;;
remove) ## NOTE: CHANGED TO 'rm' ##
	if [ $# -ne 3 ]; then
	    echo "Please enter all the required parameters."
		exit
	fi

    DOMAIN_OWNER=$2
    DOMAIN=$3
    initialize_variables

    if [ ! -d /home/$DOMAIN_OWNER ]; then
	    echo "Please enter a valid user."
		exit 
	fi

	check_domain_exists
	if [ $? = 0  ]; then
	    remove_domain
		echo -e "\033[35;1mDomain $DOMAIN removed. \033[0m"
	else
		echo -e "\033[35;1m$DOMAIN_CONFIG_PATH and/or $DOMAIN_PATH does not exist. \033[0m"
		exit
	fi
  ;;
awstats)
    if [ "$2" = "on" ]; then
        awstats_on
    elif [ "$2" = "off" ]; then
        awstats_off
    fi
  ;;
pma)
    if [ "$2" = "on" ]; then
        phpmyadmin_on
    elif [ "$2" = "off" ]; then
        phpmyadmin_off
    fi
  ;;
esac
#End execute functions#
