#!/bin/bash
#
# Starts a remote sbatch jobs and sets up correct port forwarding.
# Sample usage: bash end.sh jupyter
#               bash end.sh tensorboard

# Check if the user has given a name for the job to submit
if [ "$#" -eq 0 ]
then
    echo "Need to give name of sbatch job to run!"
    exit
fi
# Check if the helpers.sh script exists
if [ ! -f helpers.sh ]
then
    echo "Cannot find helpers.sh script!"
    exit
fi
. helpers.sh
# Parse the name of the job to submit
NAME="${1}"
# Check if the params file exists, if so read it in
PARAMS_FILE="params_${NAME}.sh"
# This function includes exceptions for if a user has params files names in the old way
check_for_params_file
source $PARAMS_FILE
# Kill job on resource
echo "Killing $NAME slurm job on ${RESOURCE}"
if [[ "$RESOURCE" == "rcc" ]]
then
	ssh ${RESOURCE} "squeue --name=$NAME --user=$RES_USERNAME -o '%A' -h | xargs --no-run-if-empty /software/slurm-current-el7-x86_64/bin/scancel"
else
	ssh ${RESOURCE} "squeue --name=$NAME --user=$RES_USERNAME -o '%A' -h | xargs --no-run-if-empty /usr/bin/scancel"

fi
echo "Killing listeners on ${RESOURCE}"
ssh ${RESOURCE} "/usr/sbin/lsof -i :$PORT -t | xargs --no-run-if-empty kill"
