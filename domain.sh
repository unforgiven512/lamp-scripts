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
		echo -e "\033[35;1mERROR: Domain check failed. Please enter a valid domain.\033[0m"
		echo -e "\033[35;1mNOTE: To disable validity checking, set DOMAIN_CHECK_VALIDITY in options.conf.\033[0m"
		return 1
	else
		return 0
	fi
else
# if $DOMAIN_CHECK_VALIDITY is "no", simply exit
	return 0
fi
} # end check_domain_valid #

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
	echo -e "\033[33;1mSelect from one of the options below:\033[0m"
	# add domain for user
	echo -n "  $0"
	echo -ne "\033[31;1m add \033[32muser \033[0m\033[36;1msub.domain.tld\033[0m"
	echo -e " - \033[34mAdd sub.domain.tld to the user's account. Awstats and log rotation will be configured.\033[0m"

	# remove domain for user
	echo -n "  $0"
	echo -ne "\033[31;1m rm \033[32muser \033[0m\033[36;1msub.domain.tld\033[0m"
	echo -e " - \033[34mDelete \033[31;1meverything\033[0m \033[34mfor sub.domain.tld.\033[0m"
	echo -e "\033[31;1m    * NOTE: THIS WILL DELETE EVERYTHING! BACKUP FILES IF NECESSARY! * \033[0m"

	# enable/disable public viewing of awstats
	# NOTE: This should be re-implemented differently for better security
	echo -n "  $0"
	echo -ne "\033[31;1m awstats \033[32mon|off\033[0m"
	echo -e " - \033[34mEnable or disable public viewing of Awstats. Stats data is preserved.\033[0m"

	# enable/disable public access to phpmyadmin
	# NOTE: This definitely needs re-implemented in a more secure way
	echo -n "  $0"
	echo -ne "\033[31;1m pma \033[32mon|off\033[0m"
	echo -e " - \033[34mEnable or disable public accessibility of phpmyadmin.\033[0m"
	echo -e "\033[31;1m    * NOTE: THIS COULD BE DANGEROUS! KEEP PRIVATE IF POSSIBLE! * \033[0m"

	echo ""
	exit
fi
