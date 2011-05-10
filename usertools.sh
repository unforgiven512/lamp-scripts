#!/bin/bash

# usertools.sh
# Gerad Munsch <gmunsch@unforgivendevelopment.com>
# `date`

# USAGE: ./usertools.sh $ACTION $USER



### FUNCTIONS ###

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
if [ ! -d /srv/www/$USER ]; then
	return 0
else
	return 1
fi
} # end function 'check_user_hosting' #


## enable web hosting for user
function enable_hosting {

# create physical directories
mkdir -p /srv/www/$USER
mkdir -p /var/log/www/$USER

# set permissions
chown $USER:www-data /srv/www/$USER
chmod 0750 /srv/www/$USER
chown root:$USER /var/log/www/$USER
chmod 0750 /var/log/www/$USER

# link directories to user's home directory
sudo -u $USER ln -s /srv/www/$USER /home/$USER/public_html
sudo -u $USER ln -s /var/log/www/$USER /home/$USER/logs

# configure php-wrapper
mkdir -p /var/www/fcgi-bin.d/php-$USER/

cat > /var/www/fcgi-bin.d/php-$USER/php-fcgi-wrapper <<EOF
#!/bin/sh
# Wrapper for PHP-fcgi
# This wrapper can be used to define settings before launching the PHP-fcgi binary.

# Define the path to php.ini. This defaults to /etc/phpX/cgi.
#export PHPRC=/var/www/fcgi-bin.d/php5-web01/phprc
#export PHPRC=/etc/php5/cgi

# Define the number of PHP childs that will be launched. Leave undefined to let PHP decide.
#export PHP_FCGI_CHILDREN=3

# Maximum requests before a process is stopped and a new one is launched
#export PHP_FCGI_MAX_REQUESTS=5000

# Launch the PHP CGI binary
# This can be any other version of PHP which is compiled with FCGI support.
exec /usr/bin/php5-cgi
EOF

chown -R $USER:$USER /var/www/fcgi-bin.d/php-$USER
chmod u+x /var/www/fcgi-bin.d/php-$USER/php-fcgi-wrapper

} # end function 'enable_hosting' #



### MAIN PROGRAM ###

## show usage information if no parameters are passed
if [ ! -n "$1" ]; then
	echo ""
	echo -e "\033[33;1mSelect an option from the list of options below:\033[0m"

	# enable web hosting for user
	echo -n "  $0"
	echo -ne "\033[31;1m enableweb \033[36muser\033[0m"
	echo -e " - \033[34mSetup directories and enable web hosting for the user. Add a domain to go live.\033[0m"

	# disable web hosting for user
	echo -n "  $0"
	echo -ne "\033[31;1m disableweb \033[36muser\033[0m"
	echo -e " - \033[34mTemporarily disable web hosting for the user. \033[31m(NOTE: Not yet implemented.)\033[0m"

	echo ""
	exit
fi

## execute options
case $1 in

enableweb)
	## enable web hosting for user
	
	# set up variables
	USER=$2

	# sanity check
	if [ $# -ne 2 ]; then
	    echo "You have entered an invalid amount of parameters, please try again."
		exit
	fi

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
		echo -e "\033[31;1mERROR: User \"$USER\" is already set up for hosting.\033[0m"
		echo -e " - \033[34mNo further action should be necessary. If problems persist, manual intervention is probably necessary.\033[0m"
		exit 1
	fi

	# enable web hosting for user
	enable_hosting
	echo "Successfully setup web hosting for $USER, enjoy."
	exit 0
;; # end case 'enableweb' #

esac

### END PROGRAM ###
