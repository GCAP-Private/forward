#!/bin/bash
#
# Sets up parameters for use with other scripts.  Should be run once.
# Sample usage: bash setup.sh

echo "First, choose the resource identifier that specifies your cluster resoure. We
will set up this name in your ssh configuration, and use it to reference the resource (sherlock)."
echo
read -p "Resource identifier (default: sherlock) > "  RESOURCE
RESOURCE=${RESOURCE:-sherlock}

echo "First, enter your Stanford username."
echo
read -p "${RESOURCE} username > "  USERNAME

echo
echo "Next, pick a port number to use.  If someone else is port forwarding using 
that port already, this script will not work.  If you pick a random number in the
range 49152-65335, you should be good."
echo
read -p "Port to use > "  PORT

echo

PARTITION="maggiori,gsb,normal,owners"
RESOURCE="sherlock"
MEM="120G"
CORES="3"
TIME="48:00:00"
CONTAINERSHARE="/scratch/users/vsochat/share"

for var in USERNAME PORT PARTITION RESOURCE MEM CORES TIME CONTAINERSHARE
do
    echo "$var="'"'"$(eval echo '$'"$var")"'"'
done >> params.sh
