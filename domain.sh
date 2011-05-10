#!/bin/bash

# domain.sh
# Gerad Munsch <gmunsch@unforgivendevelopment.com>
# `date`

# USAGE: ./domain.sh [$ARG1] [$ARG2] [...]

################################################################################
#                                                                              #
#            NOTE: THIS IS A HUGE WORK IN PROGESS -- DO NOT USE IT!            #
#                                                                              #
#                       IT *WILL* EAT YOUR CAT. TRUST ME.                      #
#                                                                              #
################################################################################

## THIS WILL BE THE FINAL DOMAIN.SH FILE ##

### INITIALIZATION ###

## load external data
source ./options.conf
source ./constants.conf

## initialize some variables
# logrotate postrotate
POSTROTATE_CMD='/etc/init.d/apache2 reload > /dev/null'

# phpmyadmin directory (NOTE: THIS SECTION MAY NOT BE NECESSARY)
# NOTE: for apt-get installed version:	/usr/share/phpmyadmin/
#       for self-installed version:	/usr/local/share/phpmyadmin/
PHPMYADMIN_PATH="/usr/share/phpmyadmin/"

# variables for awstats/phpmyadmin functions (NOTE: PROBABLY NOT NECESSARY)
# these are the paths to find the pma and awstats symlinks
FIND_PATH="/srv/www/*/*/"
VHOST_ROOT="/var/log/www/*/*/" ## not actually the vhost root, but it is where awstats is ;)

### FUNCTIONS ###

## initialize variables
function initialize_variables {
# set up path variables
DOMAIN_PATH="/srv/www/$DOMAIN_OWNER/$DOMAIN"
DOMAIN_LOG_PATH="/var/log/www/$DOMAIN_OWNER/$DOMAIN"
DOMAIN_CONFIG_PATH="/etc/apache2/sites-available/$DOMAIN"
# NOTE: may not be needed
DOMAIN_ENABLED_PATH="/etc/apache2/sites-enabled/$DOMAIN"

# setup awstats command to be placed in logrotate file
if [ $AWSTATS_ENABLE = 'yes' ]; then
	AWSTATS_CMD="/usr/share/awstats/tools/awstats_buildstaticpages.pl -update -config=$DOMAIN -dir=$DOMAIN_LOG_PATH/awstats -awstatsprog=/usr/lib/cgi-bin/awstats.pl > /dev/null"
else # NOTE: may not be needed
	AWSTATS_CMD=""
fi

# name of the logrotate file
LOGROTATE_FILE="domain-$DOMAIN"
} # end function 'initialize_variables' #


## add domain
function add_domain {
# create public_html and log directories for domain
mkdir -p $DOMAIN_PATH
mkdir -p $DOMAIN_LOG_PATH/apache2

# create placeholder index.html
cat > $DOMAIN_PATH << EOF
<html>
	<head>
		<title>Welcome to $DOMAIN</title>
	</head>
	<body>
		<h1>Welcome to $DOMAIN</h1>
		<p>This page is simply a placeholder for your domain. Place your content in the appropriate directory to see it here. Please replace or delete index.html when uploading or creating your site.</p>
		<p><b>Note to visitors:</b> Check back frequently for updates!</p>
	</body>
</html>
EOF

# setup awstats directories
if [ $AWSTATS_ENABLE = 'yes' ]; then
	mkdir -p $DOMAIN_LOG_PATH/{awstats,awstats/.data}
	cd $DOMAIN_LOG_PATH/awstats/
	sudo -u $DOMAIN_OWNER ln -s awstats.$DOMAIN.html index.html
	sudo -u $DOMAIN_OWNER ln -s /usr/share/awstats/icon awstats-icon
	cd - &> /dev/null
fi

# set permissions
chown -R $DOMAIN_OWNER:$DOMAIN_OWNER $DOMAIN_PATH
chown -R $DOMAIN_OWNER:$DOMAIN_OWNER $DOMAIN_LOG_PATH
# NOTE: these following lines may be necessary
#chmod 711 /srv/www/$DOMAIN_OWNER
#chmod 711 $DOMAIN_PATH

# build virtualhost entry
cat > $DOMAIN_CONFIG_PATH << EOF
<VirtualHost *:80>

	ServerName $DOMAIN
	ServerAlias www.$DOMAIN
	ServerAdmin webmaster@$DOMAIN
	DocumentRoot $DOMAIN_PATH
	ErrorLog $DOMAIN_LOG_PATH/apache2/error.log
	CustomLog $DOMAIN_LOG_PATH/apache2/access.log combined

	SuexecUserGroup $DOMAIN_OWNER $DOMAIN_OWNER
	Action php-fcgi /fcgi-bin/php-fcgi-wrapper
	Alias /fcgi-bin/ /var/www/fcgi-bin.d/php-$DOMAIN_OWNER/

	<Directory $DOMAIN_PATH>
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
	ServerAdmin webmaster@$DOMAIN
	DocumentRoot $DOMAIN_PATH
	ErrorLog $DOMAIN_LOG_PATH/apache2/error.log
	CustomLog $DOMAIN_LOG_PATH/apache2/access.log combined

	SuexecUserGroup $DOMAIN_OWNER $DOMAIN_OWNER
	Action php-fcgi /fcgi-bin/php-fcgi-wrapper
	Alias /fcgi-bin/ /var/www/fcgi-bin.d/php-$DOMAIN_OWNER/

	<Directory $DOMAIN_PATH>
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

# configure awstats for domain
cp /etc/awstats/awstats.conf /etc/awstats/awstats.$DOMAIN.conf
sed -i 's/^SiteDomain=.*/SiteDomain="'${DOMAIN}'"/' /etc/awstats/awstats.$DOMAIN.conf
sed -i 's/^LogFile=.*/\# deleted LogFile parameter -- appended at the bottom of this config file instead./' /etc/awstats/awstats.$DOMAIN.conf
sed -i 's/^LogFormat=.*/LogFormat=1/' /etc/awstats/awstats.$DOMAIN.conf
sed -i 's/^DirData=.*/\# deleted DirData parameter -- appended at the bottom of this config file instead./' /etc/awstats/awstats.$DOMAIN.conf
sed -i 's/^DirIcons=.*/DirIcons=".\/awstats-icon"/' /etc/awstats/awstats.$DOMAIN.conf
sed -i '/Include \"\/etc\/awstats\/awstats\.conf\.local\"/ d' /etc/awstats/awstats.$DOMAIN.conf
echo "LogFile=\"$DOMAIN_LOG_PATH/apache2/access.log\"" >> /etc/awstats/awstats.$DOMAIN.conf
echo "DirData=\"$DOMAIN_LOG_PATH/awstats/.data\"" >> /etc/awstats/awstats.$DOMAIN.conf

# add new logrotate entry for domain
cat > /etc/logrotate.d/$LOGROTATE_FILE << EOF
$DOMAIN_LOG_PATH/apache2/*.log {
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

# enable domain
a2ensite $DOMAIN
} # end function 'add_domain' #


## remove domain
function remove_domain {
# disable domain and reload web server
echo -e "\033[31;1mWARNING: THIS WILL PERMANENTLY DELETE EVERYTHING RELATED TO $DOMAIN\033[0m"
echo -e "\033[31mIf you do not have backups and/or wish to stop it, press \033[1mCTRL+C\033[0m \033[31mto abort.\033[0m"
sleep 10

# ***NOTE: THERE IS NO TURNING BACK***
# disable domain
echo -e "* Disabling domain: \033[1m$DOMAIN\033[0m"
sleep 1
a2dissite $DOMAIN

# reload apache
reload_apache

# delete awstats config
echo -e "* Removing awstats config: \033[1m/etc/awstats/awstats.$DOMAIN.conf\033[0m"
sleep 1
rm -rf /etc/awstats/awstats.$DOMAIN.conf

# delete domain files
echo -e "* Removing domain files: \033[1m$DOMAIN_PATH\033[0m"
sleep 1
rm -rf $DOMAIN_PATH

# delete vhost file
echo -e "* Removing vhost file: \033[1m$DOMAIN_CONFIG_PATH\033[0m"
sleep 1
rm -rf $DOMAIN_CONFIG_PATH

# delete log directory
echo -e "* Removing log directory: \033[1m$DOMAIN_LOG_PATH\033[0m"
sleep 1
rm -rf $DOMAIN_LOG_PATH

# delete logrotate file
echo -e "* Removing logrotate file: \033[1m/etc/logrotate.d/$LOGROTATE_FILE\033[0m"
sleep 1
rm -rf /etc/logrotate.d/$LOGROTATE_FILE
} # end function 'remove_domain' #


## check if the domain entered is actually valid as a domain name
# NOTE: to disable, set "DOMAIN_CHECK_VALIDITY" to "no" in options.conf
function check_domain_valid {
if [ "$DOMAIN_CHECK_VALIDITY" = "yes" ]; then
	if [[ "$DOMAIN" =~ [\~\!\@\#\$\%\^\&\*\(\)\_\+\=\{\}\|\\\;\:\'\"\<\>\?\,\/\[\]] ]]; then
		echo -e "\033[31;1mERROR: Domain check failed. Please enter a valid domain.\033[0m"
		echo -e "\033[34mNOTE: To disable validity checking, set \033[1mDOMAIN_CHECK_VALIDITY\033[0m \033[34min options.conf.\033[0m"
		return 1
	else
		return 0
	fi
else
# if $DOMAIN_CHECK_VALIDITY is "no", simply exit
	return 0
fi
} # end function 'check_domain_valid' #


## check if user is a real user on the system
function check_user_exists {
if [ -d /home/$USER ]; then
	return 0
else
	return 1
fi
} # end function 'check_user_exists' #


## check if user is already set up for web hosting
function check_user_hosting {
if [ -d /srv/www/$USER ]; then
	return 0
else
	return 1
fi
} # end function 'check_user_hosting' #


## check if the domain config already exists in /etc/apache2/sites-available/
function check_domain_config_exists {
if [ -e "$DOMAIN_CONFIG_PATH" ]; then
	return 0
else
	return 1
fi
} # end function 'check_domain_config_exists' #


## check if the domain path already exists in the user's web directory
function check_domain_path_exists {
if [ -e "$DOMAIN_PATH" ]; then
	return 0
else
	return 1
fi
} # end function 'check_domain_path_exists' #

## reload apache (gracefully)
function reload_apache {
apache2ctl graceful
} # end function 'reload_apache' #


################################################################################
# TEMPORARY COLOR STUFF
#######	FORMAT
#	echo -e "\033[$COLOR1;$COLOR2;$BOLD_ULm$TEXT\033[0m"
#
####### MISC
#
#	NO NEW LINE AT END OF OUTPUT: (example)
#	echo -n "WORD1"
#	echo " WORD2"
#	echo "WORD3"
#	RESULT: WORD1 WORD2
#		WORD3
#######	CODES
#	0	reset to default
#
#######	STYLE
#	1	bold
#	4	underline
#
####### TEXT COLOR
#	COLOR		FG	BG
#	-----		--	--
#	black		30	40
#	red		31	41
#	green		32	42
#	yellow		33	43
#	blue		34	44
#	magenta		35	45
#	cyan		36	46
#	white		37	47
################################################################################




### MAIN PROGRAM ###

## display usage information if no parameters are passed
if [ ! -n "$1" ]; then
	echo ""
	echo -e "\033[33;1mSelect an option from the list of options below:\033[0m"

	# add domain for user
	echo -n "  $0"
	echo -ne "\033[31;1m add \033[32muser \033[0m\033[36;1msub.domain.tld\033[0m"
	echo -e " - \033[34mAdd sub.domain.tld to the user's account. Awstats and log rotation will be configured.\033[0m"

	# remove domain for user
	echo -n "  $0"
	echo -ne "\033[31;1m rm \033[32muser \033[0m\033[36;1msub.domain.tld\033[0m"
	echo -e " - \033[34mDelete \033[1meverything\033[0m \033[34mfor sub.domain.tld.\033[0m"
	echo -e "\033[31;1m    * NOTE: THIS WILL DELETE EVERYTHING -- BACKUP FILES IF NECESSARY * \033[0m"

	# enable/disable public viewing of awstats
	# NOTE: This should be re-implemented differently for better security
	echo -n "  $0"
	echo -ne "\033[31;1m awstats \033[36mon|off\033[0m"
	echo -e " - \033[34mEnable or disable public viewing of Awstats. Stats data is preserved.\033[0m"

	# enable/disable public access to phpmyadmin
	# NOTE: This definitely needs re-implemented in a more secure way
	echo -n "  $0"
	echo -ne "\033[31;1m pma \033[36mon|off\033[0m"
	echo -e " - \033[34mEnable or disable public accessibility of phpmyadmin.\033[0m"
	echo -e "\033[31;1m    * NOTE: THIS COULD BE DANGEROUS -- KEEP PRIVATE IF POSSIBLE * \033[0m"

	echo ""
	exit
fi

## execute functions
case $1 in

add)
	## add domain for user

	# check for required parameters
	if [ $# -ne 3 ]; then
		echo -e "\033[31;1mERROR: Please enter all of the required parameters.\033[0m"
		echo -e " - \033[34mUse \033[1m$0\033[0m \033[34mto display usage options.\033[0m"
		exit
	fi

	# set up variables
	DOMAIN_OWNER=$2
	DOMAIN=$3
	initialize_variables

	# check if user exists on system
	check_user_exists
	if [ $? -ne 0 ]; then
		echo -e "\033[31;1mERROR: User \"$USER\" does not exist on this system.\033[0m"
		echo -e " - \033[34mUse \033[1madduser\033[0m \033[34m to add the user to the system.\033[0m"
		echo -e " - \033[34mFor more information, please see \033[1mman adduser\033[0m"
		exit 1
	fi

	# check if user is already set up for hosting
	check_user_hosting
	if [ $? -ne 0 ]; then
		echo -e "\033[31;1mERROR: User \"$USER\" is not set up for hosting.\033[0m"
		echo -e " - \033[34mUse \033[1m./usertools.sh enableweb user\033[0m \033[34m to set the user up for hosting.\033[0m"
		exit 1
	fi

	# check is domain is valid
	check_domain_valid
	if [ $? -ne 0 ]; then
		exit 1
	fi

	# check if domain config already exists
	check_domain_config_exists
	if [ $? -eq 0 ]; then
		echo -e "\033[31;1mERROR: $DOMAIN_CONFIG_PATH already exists. Please remove before proceeding.\033[0m"
		exit 1
	fi

	# check if domain path exists for user
	check_domain_path_exists
	if [ $? -eq 0 ]; then
		echo -e "\033[31;1mERROR: $DOMAIN_PATH already exists. Please remove before proceeding.\033[0m"
		exit 1
	fi

	# add domain
	add_domain

	# reload apache
	reload_apache

	# echo information about domain
	echo -e "blah"

;; # end case 'add' #

rm)
	## remove domain from user
;; # end case 'rm' #

awstats)
	## configure awstats
;; # end case 'awstats' #

pma)
	## configure phpmyadmin
;; # end case 'pma' #

esac

### END PROGRAM ###
