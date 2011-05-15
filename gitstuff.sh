#!/bin/bash

# gitstuff.sh
# Gerad Munsch <gmunsch@unforgivendevelopment.com>
# `date`

# USAGE: ./gitstuff.sh [ARG1] [ARG2] [...]

### NOTE:
### ALL THIS STUFF WILL BE RE-ORGANIZED AND REWRITTEN
### THIS IS MERELY TEMPORARY -- I AM WRITING THIS
### SCRIPT AS I SET EVERYTHING UP IN MY VM AS A WAY
### OF MAKING NOTES FOR MYSELF, TO FIGURE OUT EXACTLY
### WHAT IS GOING ON. I WOULD NOT RECOMMEND USING THIS
### IN ITS CURRENT STATE. PLEASE WAIT TILL THIS BECOMES
### MATURE AND THIS NOTICE IS GONE! THANKS!

source ./options.conf
source ./constants.conf

# install git, git-doc, gitweb
aptitude -y install git git-doc gitweb

# add users for git repositories
#adduser git
#adduser team

# add server-side git administrator user
#adduser gitadmin

# generate ssh key for gitadmin

# install gitolite on user 'git'

# install gitolite on user 'team'

# set up directories in gitadmin's home dir
sudo -u gitadmin mkdir -p /home/gitadmin/public
sudo -u gitadmin mkdir -p /home/gitadmin/private

# clone gitolite-admin repositories into gitadmin's home dir
sudo -u gitadmin git clone git@localhost:gitolite-admin /home/gitadmin/public/gitolite-admin
sudo -u gitadmin git clone team@localhost:gitolite-admin /home/gitadmin/private/gitolite-admin

# echo admin's ssh pubkey into /tmp/$git_admin_user_name.pub
#echo "$git_admin_ssh_pubkey" > /tmp/"$git_admin_user_name".pub

# make sure the key is readable by all
#chmod 0666 /tmp/"$git_admin_user_name".pub

# drop privs to the gitolite user, and set up gitolite
#sudo -u gitolite gl-setup /tmp/"$git_admin_user_name".pub 

# prompt user to check out gitolite-admin repository
# FIXME: (This is going to have to be improved (automated))
#echo "Please run \"git clone git@"$SERVER_IP":gitolite-admin\" on your client."

# FIXME: There will need to be some type of documentation here?


