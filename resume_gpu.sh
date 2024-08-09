#!/bin/bash
#
# Resumes an already running remote sbatch job.
# Sample usage: bash resume_gpu.sh

if [ ! -f params_gpu.sh ]
then
    echo "Need to configure params before first run, run setup_gpu.sh!"
    exit
fi
source params_gpu.sh

NAME="${1}"

# The user is required to specify port

echo "ssh ${RESOURCE} squeue --name=$NAME --user=$RES_USERNAME -o "%N" -h"
MACHINE=`ssh ${RESOURCE} squeue --name=$NAME --user=$RES_USERNAME -o "%N" -h`
ssh -L $PORT:localhost:$PORT ${RESOURCE} ssh -L $PORT:localhost:$PORT -N $MACHINE &
