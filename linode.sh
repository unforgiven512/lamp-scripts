#!/bin/bash

# linode.sh
# Gerad Munsch <gmunsch@unforgivendevelopment.com>
# Fri May  6 00:35:30 EDT 2011

# USAGE: ./linode.sh [$ARG1] [$ARG2] [...]

# import variables and constants
source options.conf
source constants.conf

# setup apt-cacher-ng if in a supported data center
function setup_apt_cacher {

} ## end setup_apt_cacher ##

# check if person is using linode
function check_if_linode {

} ## end check_if_linode ##

# set up variables for datacenter
function setup_for_datacenter {

} ## end setup_for_datacenter ##

# set up ntp
function setup_ntp {

} ## end setup_ntp ##
