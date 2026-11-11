#!/bin/bash
#
# Resumes an already running remote sbatch job.
# Sample usage: bash resume.sh

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
# The user is required to specify port
echo "ssh ${RESOURCE} squeue --name=$NAME --user=$RES_USERNAME -o \"%N\" -h"
MACHINE=`ssh ${RESOURCE} squeue --name=$NAME --user=$RES_USERNAME -o \"%N\" -h`
ssh -L ${PORT}:localhost:${PORT} ${RESOURCE} ssh -L ${PORT}:localhost:${PORT} -N $MACHINE &
