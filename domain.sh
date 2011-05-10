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


### FUNCTIONS ###
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
} # end 'check_domain_valid' #


## check if user is a real user on the system
function check_user_exists {
if [ -d /home/$USER ]; then
	return 0
else
	return 1
fi
} # end 'check_user_exists' #


## check if user is already set up for web hosting
function check_user_hosting {
if [ -d /srv/www/$USER ]; then
	return 0
else
	return 1
fi
} # end 'check_user_hosting' #

## check if the domain config already exists in /etc/apache2/sites-available/
function check_domain_config_exists {
if [ -e "$DOMAIN_CONFIG_PATH" ]; then
	return 0
else
	return 1
fi
} # end 'check_domain_config_exists' #


## check if the domain path already exists in the user's web directory
function check_domain_path_exists {
if [ -e "$DOMAIN_PATH" ]; then
	return 0
else
	return 1
fi
} # end 'check_domain_path_exists' #

## reload apache (gracefully)
function reload_apache {
apache2ctl graceful
} # end 'reload_apache' #


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
	echo -e "\033[31;1m    * NOTE: THIS WILL DELETE EVERYTHING! BACKUP FILES IF NECESSARY! * \033[0m"

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
	echo -e "\033[31;1m    * NOTE: THIS COULD BE DANGEROUS! KEEP PRIVATE IF POSSIBLE! * \033[0m"

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
