#!/bin/bash
#
# Sets up parameters for use with other scripts.  Should be run once.
# Sample usage: bash setup.sh
!/bin/bash
#
# Sets up parameters for use with other scripts.  Should be run once.
# Sample usage: bash setup.sh
echo
echo "First, enter the name of the server you are setting up your access to. This
must be either sherlock or rcc."
echo
read -p "Resource identifier (default: sherlock) > "  RESOURCE
RESOURCE=${RESOURCE:-sherlock}

# Get username
echo
echo "First, enter your username."
echo
read -p "Username > "  RES_USERNAME

# Get port number
echo
echo "Next, pick a port number to use.  If someone else is port forwarding using 
that port already, this script will not work.  If you pick a random number in the
range 49152-65335, you should be good."
echo
read -p "Port to use > "  PORT
echo

# sherlock shared settings
if [ "$RESOURCE" == "sherlock" ]; then
    PARTITION="maggiori,gsb,normal,owners"
	MEM="120G"
    CORES="3"
    TIME="48:00:00"
    CONTAINERSHARE="/scratch/users/vsochat/share"
fi

# rcc shared settings
if [ "$RESOURCE" == "rcc" ]; then
    PARTITION="neiman"
	MEM="50G"
    CORES="2"
    TIME="60:00:00"
    CONTAINERSHARE="/project2/neiman/GCAP/software/python/vsochat/share"
fi

for var in RES_USERNAME PORT PARTITION RESOURCE MEM CORES TIME CONTAINERSHARE
do
    echo "$var="'"'"$(eval echo '$'"$var")"'"'
done >> params.sh
