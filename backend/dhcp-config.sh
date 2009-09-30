#!/bin/bash

# Copyright 1999-2006 University of Chicago
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy
# of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

# For more information see: http://workspace.globus.org


#########
# ABOUT #
#########

# This script is called via sudo to adjust ebtables and dhcp policies.
# Use sudo version greater or equal to 1.6.8p2
# See: http://www.gratisoft.us/sudo/alerts/bash_functions.html

# This script must be owned and writable only by root and placed in a non-
# tamperable directory.

# SYNTAX:

# See the "adjust as necessary" section below.


########
# SUDO #
########

IFS=' '

\unalias -a

set -f -e -u -C -p -P

# set:
#
# -f
#     Disable file name generation (globbing).
# -e
#     Exit immediately if a simple command (see section Simple Commands)
#     exits with a non-zero status, unless the command that fails is part
#     of an until or while loop, part of an if statement, part of a && or
#     || list, or if the command's return status is being inverted using !
# -u
#     Treat unset variables as an error when performing parameter expansion.
#     An error message will be written to the standard error, and a
#     non-interactive shell will exit.
# -C
#     Prevent output redirection using `>', `>&', and `<>' from overwriting
#     existing files.
# -p
#     Turn on privileged mode. In this mode, the $BASH_ENV and $ENV files are
#     not processed, shell functions are not inherited from the environment,
#     and the SHELLOPTS variable, if it appears in the environment, is ignored.
#     If the shell is started with the effective user (group) id not equal to
#     the real user (group) id, and the -p option is not supplied, these
#     actions are taken and the effective user id is set to the real user id.
#     If the -p option is supplied at startup, the effective user id is not
#     reset. Turning this option off causes the effective user and group ids
#     to be set to the real user and group ids.
# -P
#     If set, do not follow symbolic links when performing commands such as cd
#     which change the current directory. The physical directory is used
#     instead. By default, Bash follows the logical chain of directories
#     when performing commands which change the current directory.

# NOTE that the -e flag is why we do some odd || checks below

PATH="/bin:/sbin:/usr/bin:/usr/local/bin"
SHELL=/bin/bash
export PATH SHELL

unset -f strlen
function strlen (){
    eval echo "\${#${1}}"
}


#######################
# ADJUST AS NECESSARY #
#######################

# Policy file for script to adjust
#DHCPD_CONF="/etc/dhcp/dhcpd.conf"
DHCPD_CONF="/etc/dhcpd.conf"

# Command to run before policy adjustment
DHCPD_STOP="/etc/init.d/dhcpd stop"

# Command to run after policy adjustment
DHCPD_START="/etc/init.d/dhcpd start"

# Sleep between stop and start? in seconds
SLEEP=0

# If DIRNAME is not available and commented out, you must adjust these
# files to their absolute paths. By default, $DIRNAME is used to find
# the DHCP_CONF_ALTER and EBTABLES_CONFIG scripts, the assumption being
# that they are in the same directory as this script (dhcp-config.sh).
DHCP_CONF_ALTER="dhcp-conf-alter.py"
EBTABLES_CONFIG="ebtables-config.sh"

DIRNAME="dirname"

function die_dirname() {
  echo "ERROR: DIRNAME invocation failed.  Suggestion: use hardcoded"
  echo "       paths to $DHCP_CONF_ALTER and $EBTABLES_CONFIG"
  exit 1
}

if [ "X$DIRNAME" != "X" ]; then
  # get the current directory of this script (dhcp-config.sh)
  curdir=`$DIRNAME $0` || die_dirname

  DHCP_CONF_ALTER=$curdir/$DHCP_CONF_ALTER
  EBTABLES_CONFIG=$curdir/$EBTABLES_CONFIG
fi

# Instead of adjusting DHCP_CONF_ALTER and EBTABLES_CONFIG (if it is
# necessary), you could also just hardcode these CMDs if you want to,
# DHCP_CONF_ALTER and EBTABLES_CONFIG are not used again after this
DHCP_CONF_ALTER_CMD="python $DHCP_CONF_ALTER"
EBTABLES_CONFIG_CMD="bash $EBTABLES_CONFIG"

echo "DHCP_CONF_ALTER_CMD: $DHCP_CONF_ALTER_CMD"
echo "EBTABLES_CONFIG_CMD: $EBTABLES_CONFIG_CMD"

unset DHCP_CONF_ALTER
unset EBTABLES_CONFIG
unset DIRNAME
unset curdir

unset PYTHONPATH
unset PYTHONINSPECT

#############
# ARGUMENTS #
#############

if [ $# -lt 3 ]; then
  echo "ERROR: requires at least 3 arguments. Syntax: add|rem <vifname> <ipaddr> [<dhcpif> <macaddr> <broadcast> <subnetmask> <gateway> <hostname>]"
  exit 1
fi

ADDREM=$1
echo "  subcommand: $ADDREM"
VIFNAME=$2
echo "     vifname: $VIFNAME"
IPADDR=$3
echo "      ipaddr: $IPADDR"

if [ "$ADDREM" != "add" ] && [ "$ADDREM" != "rem" ]; then
  echo "ERROR: subcommand must be 'add' or 'rem'"
  exit 1
fi

if [ "$ADDREM" = "rem" ] && [ $# -ne 3 ]; then
  echo "ERROR: rem requires just 3 arguments: rem <vifname> <ipaddr>"
  exit 1
fi

if [ "$ADDREM" = "add" ]; then
  if [ $# -ne 11 ]; then
    echo "ERROR: add requires 11 arguments: add <vifname> <ipaddr> <dhcpif> <macaddr> <broadcast> <subnetmask> <gateway> <hostname> <dns1> <dns2>"
    echo "(These can be 'none': broadcast, subnetmask, gateway, dns1, dns2)"
    exit 1
  else
    DHCPIF=$4
    echo "      dhcpif: $DHCPIF"
    MACADDR=$5
    echo "     macaddr: $MACADDR"
    BROADCAST=$6
    echo "   broadcast: $BROADCAST"
    SUBNETMASK=$7
    echo "  subnetmask: $SUBNETMASK"
    GATEWAY=$8
    echo "     gateway: $GATEWAY"
    HOSTNAME=$9
    echo "    hostname: $HOSTNAME"
    shift
    DNS1=$9
    echo "        dns1: $DNS1"
    shift
    DNS2=$9
    echo "        dns2: $DNS2"
  fi
fi

#############################
#### EBTABLES ADJUSTMENT ####
#############################

SUCCESS="y"

if [ "$ADDREM" = "rem" ]; then
  echo "CMD: $EBTABLES_CONFIG_CMD rem $VIFNAME"
  $EBTABLES_CONFIG_CMD rem $VIFNAME || SUCCESS="n"
  if [ "$SUCCESS" != "y" ]; then
    echo "ERROR: ebtables remove failed"
  else
    echo "ebtables remove succeeded"
  fi
fi

function die_ebtables() {
  echo "ERROR: ebtables addition failed"
  exit 1
}

if [ "$ADDREM" = "add" ]; then
  echo "CMD: $EBTABLES_CONFIG_CMD add $VIFNAME $DHCPIF $MACADDR $IPADDR"
  $EBTABLES_CONFIG_CMD add $VIFNAME $DHCPIF $MACADDR $IPADDR || die_ebtables
  echo "ebtables addition succeeded"
fi

##########################
#### DHCPD ADJUSTMENT ####
##########################

function die_dhcpd_stop_ok() {
  echo "ERROR: dhcp stop failed (ok)"
}

function die_dhcpd_remove() {
  echo "ERROR: dhcp policy remove failed"
  SUCCESS="n"
}

function die_dhcpd_start() {
  echo "ERROR: dhcp start failed"
  SUCCESS="n"
}

function die_dhcpd_alter() {
  echo "ERROR: dhcp policy addition failed"
  SUCCESS="n" # still restart
}

# LOCKING 

TEMPFILE="$0.$$"
LOCKFILE="$0.lock"

set +e

function my_lockfile ()
{
    echo $$ > $TEMPFILE || {
            echo "You don't have permission to access `dirname $TEMPFILE`"
            return 1
    }

    ln $TEMPFILE $LOCKFILE && {
            rm -f $TEMPFILE
            return 0
    }

    rm -f $TEMPFILE
    return 1
}

function stale_check ()
{
  PID=""
  PID=`cat $LOCKFILE`
  if [ "X$PID" != "X" ]; then
    echo "checking if LOCKFILE pid $PID is stale"
    kill -0 $PID
    if [ $? != 0 ]; then
      echo "pid $PID does not exist, removing lockfile"
      rm -f $LOCKFILE
    fi
  fi
}

# wait for a lock
num=5
until my_lockfile ; do
    sleep 0.1

    num=`expr $num - 1`
    if [ $num = 0 ]; then
      stale_check
      num=5
    fi
done


if [ "$ADDREM" = "rem" ]; then
  echo "CMD: $DHCPD_STOP"
  $DHCPD_STOP || die_dhcpd_stop_ok

  echo "CMD: $DHCP_CONF_ALTER_CMD -r -i $IPADDR -p $DHCPD_CONF"
  x=1
  $DHCP_CONF_ALTER_CMD -r -i $IPADDR -p $DHCPD_CONF && x=0 || die_dhcpd_remove
  if [ $x -eq 0 ]; then
    echo "dhcp policy remove succeeded"
  fi

  if [ "$SLEEP" -ne "0" ]; then
    echo "Sleeping for $SLEEP seconds."
    sleep $SLEEP
  fi
  
  echo "CMD: $DHCPD_START"
  $DHCPD_START || die_dhcpd_start
fi


if [ "$ADDREM" = "add" ]; then
  ARGS="-a -i $IPADDR -m $MACADDR -n $HOSTNAME -p $DHCPD_CONF"
  
  if [ "$BROADCAST" != "none" ]; then
    ARGS="$ARGS -b $BROADCAST"
  fi
  
  if [ "$SUBNETMASK" != "none" ]; then
    ARGS="$ARGS -s $SUBNETMASK"
  fi
  
  if [ "$GATEWAY" != "none" ]; then
    ARGS="$ARGS -g $GATEWAY"
  fi

  if [ "$DNS1" != "none" ] && [ "$DNS2" != "none" ]; then
    ARGS="$ARGS -d $DNS1,$DNS2"
  else 
    if [ "$DNS1" != "none" ]; then
      ARGS="$ARGS -d $DNS1"
    fi
    if [ "$DNS2" != "none" ]; then
      ARGS="$ARGS -d $DNS2"
    fi
  fi

  echo "CMD: $DHCPD_STOP"
  $DHCPD_STOP || die_dhcpd_stop_ok
    
  echo "CMD: $DHCP_CONF_ALTER_CMD $ARGS"
  
  x=1
  $DHCP_CONF_ALTER_CMD $ARGS && x=0 || die_dhcpd_alter
  if [ $x -eq 0 ]; then
    echo "dhcp policy addition succeeded"
  fi
  
  if [ "$SLEEP" -ne "0" ]; then
    echo "Sleeping for $SLEEP seconds."
    sleep $SLEEP
  fi
  
  echo "CMD: $DHCPD_START"
  $DHCPD_START || die_dhcpd_start
fi

rm -f $LOCKFILE

if [ "$SUCCESS" = "n" ]; then
  exit 1
fi

