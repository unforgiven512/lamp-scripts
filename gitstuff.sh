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

# install git, git-doc, gitweb, gitolite
aptitude -y install git git-doc gitweb gitolite


