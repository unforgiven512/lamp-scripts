#!/bin/bash

# domain.sh
# Gerad Munsch <gmunsch@unforgivendevelopment.com>
# `date`

# USAGE: ./$SCRIPT_NAME.sh [$ARG1] [$ARG2] [...]

## NOTICE: THIS FILE HAS BEEN DEPRECATED AND WILL BE DELETED FROM FINAL RELEASE

################################################################################
#                                                                              #
#            NOTE: THIS IS A HUGE WORK IN PROGESS -- DO NOT USE IT!            #
#                                                                              #
#                       IT *WILL* EAT YOUR CAT. TRUST ME.                      #
#                                                                              #
################################################################################

#Edit value below if you wish to use the backup functions
source ./options.conf

#Check domain to see if it contains invalid characters. Option = yes|no.
checkvalidity=yes



###Functions Begin###

function add_domain {

if [ ! -d /home/$USER ]; then
echo "User $USER does not exist. Exiting"
exit
fi

#Create public_html, awstats and log directories for domain
mkdir -p /home/$USER/domains/$DOMAIN/public_html/cgi-bin /home/$USER/domains/$DOMAIN/{logs,awstats,awstats/.data}
cat > /home/$USER/domains/$DOMAIN/public_html/robots.txt <<EOF
User-agent: *
Disallow: /stats/
EOF

cat > /home/$USER/domains/$DOMAIN/public_html/index.html <<EOF
Welcome to the default placeholder!
Overwrite or remove index.html when uploading your site. 
EOF
chown -R $USER:$USER /home/$USER/domains

#Setup awstats directories
cd /home/$USER/domains/$DOMAIN/awstats/
ln -s awstats.$DOMAIN.html index.html
ln -s /usr/share/awstats/icon awstats-icon
cd -
ln -s ../awstats /home/$USER/domains/$DOMAIN/public_html/stats 
#Add phpmyadmin to domain
ln -s /usr/share/phpmyadmin/ /home/$USER/domains/$DOMAIN/public_html/p

#Virtualhost entry
cat > /etc/apache2/sites-available/$DOMAIN <<EOF
<VirtualHost *:80>

    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    ServerAdmin admin@$DOMAIN
    DocumentRoot /home/$USER/domains/$DOMAIN/public_html/
    ErrorLog /home/$USER/domains/$DOMAIN/logs/error.log
    CustomLog /home/$USER/domains/$DOMAIN/logs/access.log combined

    SuexecUserGroup $USER $USER
    Action php-fcgi /fcgi-bin/php-fcgi-wrapper
    Alias /fcgi-bin/ /var/www/fcgi-bin.d/php-$USER/

    <Directory /home/$USER/domains/$DOMAIN/public_html>
    	Options Indexes FollowSymLinks
    	AllowOverride All
    	Order allow,deny
    	allow from all
    </Directory>

</VirtualHost>


<IfModule mod_ssl.c>
<VirtualHost *:443>

    ServerName $DOMAIN
    ServerAlias www.$DOMAIN
    ServerAdmin admin@$DOMAIN
    DocumentRoot /home/$USER/domains/$DOMAIN/public_html/
    ErrorLog /home/$USER/domains/$DOMAIN/logs/error.log
    CustomLog /home/$USER/domains/$DOMAIN/logs/access.log combined

    SuexecUserGroup $USER $USER
    Action php-fcgi /fcgi-bin/php-fcgi-wrapper
    Alias /fcgi-bin/ /var/www/fcgi-bin.d/php-$USER/

    <Directory /home/$USER/domains/$DOMAIN/public_html>
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

# deleted stuff

#Configures Awstats for domain
cp /etc/awstats/awstats.conf /etc/awstats/awstats.$DOMAIN.conf
sed -i 's/^SiteDomain=.*/SiteDomain="'${DOMAIN}'"/' /etc/awstats/awstats.$DOMAIN.conf
sed -i 's/^LogFile=.*/LogFile="\/home\/'${USER}'\/domains\/'${DOMAIN}'\/logs\/access.log"/' /etc/awstats/awstats.$DOMAIN.conf
sed -i 's/^DirData=.*/DirData="\/home\/'${USER}'\/domains\/'${DOMAIN}'\/awstats\/\.data"/' /etc/awstats/awstats.$DOMAIN.conf
sed -i 's/^DirIcons=.*/DirIcons=".\/awstats-icon"/' /etc/awstats/awstats.$DOMAIN.conf

#If logrotate virtualhost file exists, append new domain data to setup Awstats for domain
if [ -e "/etc/logrotate.d/virtualhosts" ]; then
    sed -i 's/^\/home\/'${USER}'\/domains\/'${DOMAIN}'\/logs\/\*.log &/' /etc/logrotate.d/virtualhosts
    sed -i '/prerotate/ a\\t\t\/usr\/share\/awstats\/tools\/awstats_buildstaticpages.pl -update -config='${DOMAIN}' -dir=\/home\/'${USER}'\/domains\/'${DOMAIN}'\/awstats -awstatsprog=\/usr\/lib\/cgi-bin\/awstats.pl \> /dev/null' /etc/logrotate.d/virtualhosts

else
#if doesn't exist, create a new logrotate virtualhost file

    cp /etc/logrotate.d/apache2 /etc/logrotate.d/virtualhosts
    #Add log directory before the default /var/log line 
    sed -i 's/\/var\/log/\/home\/'${USER}'\/domains\/'${DOMAIN}'\/logs\/\*.log &/' /etc/logrotate.d/virtualhosts
    #Space is added after 'log' in the line below to account for the spacing before curly braces {
    #Remove default /var/log path
    sed -i 's/\/var\/log\/apache2\/\*\.log //' /etc/logrotate.d/virtualhosts
    sed -i 's/\tweekly/\tdaily/' /etc/logrotate.d/virtualhosts
    #Keep 10 days of rotated files
    sed -i 's/\trotate .*/\trotate 10/' /etc/logrotate.d/virtualhosts
    #Add prerotate and endscript line for Awstats
    sed -i '/sharedscripts/ a\\tprerotate' /etc/logrotate.d/virtualhosts
    sed -i '/prerotate/ a\\tendscript' /etc/logrotate.d/virtualhosts
    #Command to update Awstats for domain
    sed -i '/prerotate/ a\\t\t\/usr\/share\/awstats\/tools\/awstats_buildstaticpages.pl -update -config='${DOMAIN}' -dir=\/home\/'${USER}'\/domains\/'${DOMAIN}'\/awstats -awstatsprog=\/usr\/lib\/cgi-bin\/awstats.pl \> /dev/null' /etc/logrotate.d/virtualhosts
fi


a2ensite $DOMAIN
apache2ctl graceful
echo "Apache reloaded"
} #end of add_domain function

function check_empty_logrotate_virtualhost {

#if no more virtual domains are present, delete the logrotate file.

#Find the term /home and append new line to it so that the number of lines can be counted by grep
virtual_domains=`head -n 1 /etc/logrotate.d/virtualhosts | grep -c "\/home\/"`

if [ $virtual_domains -lt 1 ]; then
echo -e "\033[35;1mNo virtual domains available, removing /etc/logrotate.d/virtualhosts \033[0m"
rm -rf /etc/logrotate.d/virtualhosts
fi

} #end of check_empty_logrotate_virtualhost function


function configure_namevirtualhost {

#Remove line with *:80, commented out because Varnish cache doesn't work without it
#sed -i '/NameVirtualHost \*:80/ d' /etc/apache2/ports.conf

#Add virtualhost IP :80
sed -i '/Listen 80/ i\NameVirtualHost '${virtualhostIP}':80' /etc/apache2/ports.conf

#Add virtualhost IP :443
sed -i '/<IfModule mod_ssl.c>/ a\    NameVirtualHost '${virtualhostIP}':443' /etc/apache2/ports.conf

}  #end of configure_namevirtualhost function


function remove_domain {

if [ ! -d /home/$USER/domains/$DOMAIN ]; then
echo "User $USER or $DOMAIN does not exist. Exiting"
exit
fi

a2dissite $DOMAIN
apache2ctl graceful
echo "Apache reloaded"

rm -rf /etc/awstats/awstats.$DOMAIN.conf
rm -rf /home/$USER/domains/$DOMAIN
rm -rf /etc/apache2/sites-available/$DOMAIN
sed -i 's/\/home\/'${USER}'\/domains\/'${DOMAIN}'\/logs\/\*.log //' /etc/logrotate.d/virtualhosts
sed -i '/\t\t\/usr\/share\/awstats\/tools\/awstats_buildstaticpages.pl -update -config='${DOMAIN}' -dir=\/home\/'${USER}'\/domains\/'${DOMAIN}'\/awstats -awstatsprog=\/usr\/lib\/cgi-bin\/awstats.pl/ d' /etc/logrotate.d/virtualhosts
} #end of remove_domain function



function create_backup_directory {

if [ -d "/home/$USER" ]; then
    mkdir -p /home/$USER/backup/{database,domain}
    chown -R $USER:$USER /home/$USER/backup
    echo -e "\033[35;1mBackup folders created in /home/$USER/backup.\033[0m"
else
    echo -e "\033[35;1mERROR: User /home/$USER doesn't exist.\033[0m"
fi
}

function cron_backupdb {

    if [ "$INTERVAL" != "daily" ] && [ "$INTERVAL" != "weekly" ] && [ "$INTERVAL" != "monthly" ]; then
        echo -e "\033[35;1mERROR: Please enter a valid interval - daily, weekly or monthly.\033[0m"
        return 1
    fi

	crontab -l > ~/tmpcron.txt
	tmp=`grep -w "@$INTERVAL mysqldump -hlocalhost -uroot -p$MYSQL_ROOT_PASSWORD $DATABASENAME" ~/tmpcron.txt | wc -l`
	command rm ~/tmpcron.txt

    if [ $tmp -gt 0 ]; then
	    echo -e "\033[35;1mERROR: Database backup already exists, please remove it from crontab -e before entering again.\033[0m"
        return 1
	fi

    if [ ! -d "/home/$USER/backup/database" ]; then
	    echo -e "\033[35;1mERROR: Database folder /home/$USER/backup/database doesn't exist, please create it first.\033[0m"
	    return 1
    fi

crontab -l > ~/tmpcron.txt
cat >> ~/tmpcron.txt <<EOF
@$INTERVAL mysqldump -hlocalhost -uroot -p$MYSQL_ROOT_PASSWORD $DATABASENAME > /home/$USER/backup/database/$DATABASENAME.\`/bin/date +\%Y\%m\%d\`.sql; chown $USER:$USER /home/$USER/backup/database/*
EOF
crontab ~/tmpcron.txt
command rm ~/tmpcron.txt
echo -e "\033[35;1mDatabase $DATABASENAME will be backed up to /home/$USER/backup/database/$DATABASENAME $INTERVAL.\033[0m"
echo -e "\033[35;1mTo verify, enter crontab -e.\033[0m"
}


function cron_backupdomain {

    if [ "$INTERVAL" != "daily" ] && [ "$INTERVAL" != "weekly" ] && [ "$INTERVAL" != "monthly" ]; then
        echo -e "\033[35;1mERROR: Please enter a valid interval - daily, weekly or monthly.\033[0m"
        return 1
    fi

	crontab -l > ~/tmpcron.txt
    tmp=`grep -w "home/*/domains/$DOMAIN" ~/tmpcron.txt | wc -l`
	command rm ~/tmpcron.txt

    if [ $tmp -gt 0 ]; then
	    echo -e "\033[35;1mERROR: Domain backup cronjob already exists, please remove it from crontab -e before trying again.\033[0m"
        return 1
	fi

    if [ ! -d "/home/$USER/backup/domain" ]; then
	    echo -e "\033[35;1mERROR: Backup folder /home/$USER/backup/domain doesn't exist, please create it first.\033[0m"
	    return 1
	fi

	if [ ! -d "/home/$USER/domains/$DOMAIN" ]; then
        echo -e "\033[35;1mERROR: Domain does not exist in /home/$USER/domains/$DOMAIN. Please enter a valid domain.\033[0m"
        return 1
    fi

crontab -l > ~/tmpcron.txt
cat >> ~/tmpcron.txt <<EOF
@$INTERVAL tar -czf /home/$USER/backup/domain/$DOMAIN.\`/bin/date +\%Y\%m\%d\`.tar.gz -C / home/$USER/domains/$DOMAIN; chown $USER:$USER /home/$USER/backup/domain/*
EOF

crontab ~/tmpcron.txt
command rm ~/tmpcron.txt
echo -e "\033[35;1mDomain $DOMAIN will be backed up to /home/$USER/backup/domain/$DOMAIN $INTERVAL.\033[0m"
echo -e "\033[35;1mTo verify, enter crontab -e.\033[0m"
}

function cron_cleanbackup {

    if [ "$INTERVAL" != "daily" ] && [ "$INTERVAL" != "weekly" ] && [ "$INTERVAL" != "monthly" ]; then
        echo -e "\033[35;1mERROR: Please enter a valid interval - daily, weekly or monthly.\033[0m"
        return 1
    fi

    if [ ! -d "/home/$USER" ]; then
	    echo -e "\033[35;1mERROR: Folder /home/$USER/backup doesn't exist, type in a valid system user.\033[0m"
	    return 1
	fi

    if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
        echo -e "\033[35;1mERROR: Please enter a valid \"Days\" integer.\033[0m"
	    return 1
	fi

crontab -l > ~/tmpcron.txt
sed -i '/cleanbackup.log/ d' ~/tmpcron.txt
cat >> ~/tmpcron.txt <<EOF
@$INTERVAL find /home/$USER/backup/* -mtime +$DAYS -exec rm -rfv {} \; > /home/$USER/cleanbackup.log
EOF
crontab ~/tmpcron.txt
command rm ~/tmpcron.txt
echo -e "\033[35;1mBackup files older than $DAYS days will be removed from /home/$USER/backup.\033[0m"
echo -e "\033[35;1mTo verify, enter crontab -e.\033[0m"
}


function check_domain_exists {
if [ -e "/etc/apache2/sites-available/$DOMAIN" ]; then
	return 0
	else
	return 1
fi
}


function check_domain_valid {
if [ "$checkvalidity" = "yes" ]; then
    if [[ "$DOMAIN" =~ [\~\!\@\#\$\%\^\&\*\(\)\_\+\=\{\}\|\\\;\:\'\"\<\>\?\,\/\[\]] ]]; then
        echo -e "\033[35;1mERROR: Domain check failed. Please enter a valid domain.\033[0m"
        echo -e "\033[35;1mERROR: If you are certain this domain is valid, then disable domain checking option at the beginning of the script.\033[0m"
        return 1
    else
        return 0
    fi
else 
    return 0
fi
}


function awstats_off {

rm -rfv /home/*/domains/*/public_html/stats
echo -e "\033[35;1mAwstats disabled. If you do not see any removed messages, it means it has already been disabled.\033[0m"
} #end of stats_off

function awstats_on {

test=`find /home/*/domains/*/public_html/ -maxdepth 1 -iname "stats" -print0 | xargs -0 -I path echo path | wc -l`
if [ $test -eq 0 ]; then
find /home/*/domains/* -maxdepth 1 -name "public_html" -type d | xargs -L1 -I path ln -sv ../awstats path/stats
echo -e "\033[35;1mAwstats enabled.\033[0m"
else
echo -e "\033[35;1mERROR: Awstats already enabled for at least 1 domain. Exiting... \033[0m"
echo -e "\033[35;1mERROR: Turn it off again before re-enabling Awstats for all domains. \033[0m"
fi
} #end of stats_on

function phpmyadmin_off {

rm -rfv /home/*/domains/*/public_html/p
echo -e "\033[35;1mPhpmyadmin disabled. If you do not see any removed messages, it means it has already been disabled.\033[0m"
} #end of phpmyadmin_off 


function phpmyadmin_on {

test=`find /home/*/domains/*/public_html/ -maxdepth 1 -iname "p" -print0 | xargs -0 -I path echo path | wc -l`
if [ $test -eq 0 ]; then
find /home/*/domains/* -maxdepth 1 -name "public_html" -type d | xargs -L1 -I path ln -sv /usr/share/phpmyadmin/ path/p
echo -e "\033[35;1mPhpmyadmin enabled.\033[0m"
else
echo -e "\033[35;1mERROR: Phpmyadmin already enabled for at least 1 domain. Exiting... \033[0m"
echo -e "\033[35;1mERROR: Turn it off again before re-enabling Phpmyadmin for all domains. \033[0m"
fi

} #end of phpmyadmin_on


####Main program begins####

if [ ! -n "$1" ]; then
    echo ""
    echo -e "\033[35;1mSelect from the options below to use this script:- \033[0m"
    echo -n  "$0"
    echo -ne "\033[36m add Domain.tld Username\033[0m"
    echo     " - Add specified domain to User's home directory. Awstats, Phpmyadmin and log rotation will be configured."

    echo -n  "$0"
    echo -ne "\033[36m remove Domain.tld Username\033[0m"
    echo     " - Remove everything for Domain.tld including stats and public_html. If necessary, backup domain files before executing!"

    echo -n  "$0"
    echo -ne "\033[36m addip IP_Addr\033[0m"
    echo     " - Add a NameVirtualHost IP to Apache ports.conf. Recommended to add all available server IPs."

    echo -n  "$0"
    echo -ne "\033[36m awstats on|off\033[0m"
    echo     " - Disable or enable public viewing of Awstats. Stats data is preserved."

    echo -n  "$0"
    echo -ne "\033[36m phpmyadmin on|off\033[0m"
    echo     " - Disable or enable access to Phpmyadmin. If using weak MySQL root password, it is best to disable Phpmyadmin when not in use."

    echo ""
    exit
fi

#Start execute functions#
case $1 in
add)
    DOMAIN=$2
    USER=$3
	if [ $# -ne 3 ]; then
	    echo "Please enter all the required parameters."
		exit
	fi
    
    check_domain_valid
    if [ $? -ne 0 ]; then
        exit 1
	fi

	check_domain_exists
	if [  $? -eq 0  ]; then
	    echo -e "\033[35;1m/etc/apache2/sites-available/$DOMAIN already exists, please remove the existing domain first before adding it again. \033[0m" 
		exit
	else
		add_domain
		echo -e "\033[35;1mDomain $DOMAIN added. \033[0m"
		echo -e "\033[35;1mYou can now upload your site to /home/$USER/domains/$DOMAIN/public_html. \033[0m"
		echo -e "\033[35;1mPhpmyadmin can be accessed via https://$DOMAIN/p. Note the HTTP[S] address. \033[0m"
		echo -e "\033[35;1mAwstats for $DOMAIN can be accessed via http://$DOMAIN/stats. \033[0m"
		echo -e "\033[35;1mStats are updated daily. Allow 24H before viewing stats or you will be greeted with forbidden error page. \033[0m"
        echo -e "\033[35;1mIf Varnish cache is enabled, please enable it again using serversetup.sh to reconfigure this domain. \033[0m"
	fi
  ;;
addip)
    virtualhostIP=$2
    configure_namevirtualhost
    apache2ctl restart >/dev/null 2>&1
    echo -e "\033[35;1mNameVirtualHost $2:80 and NameVirtualHost $2:443 has been added to /etc/apache2/ports.conf. \033[0m"
    echo -e "\033[35;1mApache reloaded. \033[0m"
  ;;
remove)
	DOMAIN=$2
    USER=$3

	if [ $# -ne 3 ]; then
	    echo "Please enter all the required parameters."
		exit
	fi

	check_domain_exists
	if [ $? = 0  ]; then
	    remove_domain
		check_empty_logrotate_virtualhost
		echo -e "\033[35;1mDomain $DOMAIN removed. \033[0m"
	else
		echo -e "\033[35;1m/etc/apache2/sites-available/$DOMAIN does not exist. \033[0m"
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
 phpmyadmin)
    if [ "$2" = "on" ]; then
        phpmyadmin_on
    elif [ "$2" = "off" ]; then
        phpmyadmin_off
    fi
  ;;
esac
#End execute functions#
