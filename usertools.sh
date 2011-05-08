#!/bin/bash

# usertools.sh
# Gerad Munsch <gmunsch@unforgivendevelopment.com>
# `date`

# USAGE: ./usertools.sh $ACTION $USER





## check if user is a real user on the system ##
function check_user_exists {
if [ -d /home/$USER ]; then
	return 0
else
	return 1
fi
} ## end check_user_exists ##





## check if user is already set up for web hosting ##
function check_user_hosting {
if [ ! -d /srv/www/$USER ]; then
	return 0
else
	return 1
fi
} ## end check_user_hosting ##





## enable web hosting ##
function enable_hosting {

# create physical directories
mkdir -p /srv/www/$USER
mkdir -p /var/log/www/$USER

# set permissions
chown $USER:$USER /srv/www/$USER

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

} ## end enable_hosting ##





## main program ##
# show menu
if [ ! -n "$1" ]; then
	echo ""
	echo -e "\033[35;1mUse one of the commands listed below:\033[0m"
	# enable web hosting for USERNAME
	echo -n  "$0"
	echo -ne "\033[36m enableweb USERNAME\033[0m"
	echo     " - Setup directories and enable web hosting for USERNAME. Add a domain to go live."

	# disable web hosting for USERNAME
    echo -n  "$0"
    echo -ne "\033[36m disableweb USERNAME\033[0m"
    echo     " - Temporarily disable web hosting for USERNAME. (NOTE: Not yet implemented.)"

    echo ""
    exit
fi
# execute options
case $1 in
enableweb)
	USER=$2

	# sanity check
	if [ $# -ne 2 ]; then
	    echo "You have entered an invalid amount of parameters, please try again."
		exit
	fi

	# check if user exists on system
	check_user_exists
	if [ $? -ne 0 ]; then
		echo "User \"$USER\" does not exist on this system."
		exit 1
	fi

	# check if user is already set up for hosting
	check_user_hosting
	if [ $? -ne 0 ]; then
		echo "User \"$USER\" is already set up for hosting."
		exit 1
	fi

	# enable web hosting for user
	enable_hosting
	echo "Successfully setup web hosting for $USER, enjoy!"
	exit 0
;; ## end enableweb ##
esac
