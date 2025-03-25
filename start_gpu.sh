#!/bin/bash
#
# Starts a remote sbatch jobs and sets up correct port forwarding.
# This version also activates GPUs.
# Sample usage: bash start.sh sherlock/singularity-jupyter 
#               bash start.sh sherlock/singularity-jupyter /home/users/raphtown
#               bash start.sh sherlock/singularity-jupyter /home/users/raphtown

if [ ! -f params_gpu.sh ]
then
    echo "Need to configure params before first run, run setup.sh!"
    exit
fi
. params_gpu.sh

if [ "$#" -eq 0 ]
then
    echo "Need to give name of sbatch job to run!"
    exit
fi

if [ ! -f helpers.sh ]
then
    echo "Cannot find helpers.sh script!"
    exit
fi
. helpers.sh

NAME="${1:-}"

# The user could request either <resource>/<script>.sbatch or
#                               <name>.sbatch
SBATCH="$NAME.sbatch"

# set FORWARD_SCRIPT and FOUND
set_forward_script
check_previous_submit

echo
echo "== Getting destination directory =="
RESOURCE_HOME=`ssh ${RESOURCE} pwd`
ssh ${RESOURCE} mkdir -p $RESOURCE_HOME/forward-util

echo
echo "== Uploading sbatch script =="
scp $FORWARD_SCRIPT ${RESOURCE}:$RESOURCE_HOME/forward-util/

# adjust PARTITION if necessary
set_partition
echo

echo "== Submitting sbatch =="

SBATCH_NAME=$(basename $SBATCH)

if [ "$CONSTRAINT_H100" -eq 1 ]
then
    echo "GPU constrained to H100"
    command="sbatch
        --job-name=$NAME
        --partition=$PARTITION
        --ntasks=$CORES
        --gpus=$GPUS
        --constraint=GPU_SKU:H100_SXM5
        --nodes=1
        --output=$RESOURCE_HOME/forward-util/$SBATCH_NAME.out
        --error=$RESOURCE_HOME/forward-util/$SBATCH_NAME.err
        --mem=$MEM
        --time=$TIME
        $RESOURCE_HOME/forward-util/$SBATCH_NAME $PORT \"${@:2}\""
else
    command="sbatch
        --job-name=$NAME
        --partition=$PARTITION
        --ntasks=$CORES
        --gpus=$GPUS
        --nodes=1
        --output=$RESOURCE_HOME/forward-util/$SBATCH_NAME.out
        --error=$RESOURCE_HOME/forward-util/$SBATCH_NAME.err
        --mem=$MEM
        --time=$TIME
        $RESOURCE_HOME/forward-util/$SBATCH_NAME $PORT \"${@:2}\""
fi



echo ${command}
ssh ${RESOURCE} ${command}

# Tell the user how to debug before trying
instruction_get_logs

# Wait for the node allocation, get identifier
get_machine
echo "notebook running on $MACHINE"

setup_port_forwarding

sleep 10
echo "== Connecting to notebook =="

# Print logs for the user, in case needed
print_logs

echo

instruction_get_logs
echo
echo "== Instructions =="
echo "1. Password, output, and error printed to this terminal? Look at logs (see instruction above)"
echo "2. Browser: http://sh-02-21.int:$PORT/ -> http://localhost:$PORT/..."
echo "3. To end session: bash end.sh ${NAME}"
