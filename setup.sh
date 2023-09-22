#!/bin/bash
#
# Sets up parameters for use with other scripts.  Should be run once.
# Sample usage: bash setup.sh

echo
echo "First, enter your Stanford username."
echo
read -p "Stanford username > "  USERNAME

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
