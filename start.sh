#!/bin/bash
#
# Starts a remote sbatch jobs and sets up correct port forwarding.
# This version also activates GPUs.
# Sample usage: bash start_gpu.sh sherlock/singularity-jupyter 
#               bash start_gpu.sh sherlock/singularity-jupyter /home/users/raphtown
#               bash start_gpu.sh sherlock/singularity-jupyter /home/users/raphtown

# Check if the user has given a name for the job to submit
if [ "$#" -eq 0 ]
then
    echo "Need to give name of sbatch job to run! Enter gcap_jlab if you unsure."
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
# The user could request either <resource>/<script>.sbatch or
#                               <name>.sbatch
NAME="${1:-}"
SBATCH="$NAME.sbatch"
SBATCH_NAME=$(basename $SBATCH)
# Check if the params file exists, if so read it in
PARAMS_FILE="params_${NAME}.sh"
# This function includes exceptions for if a user has params files names in the old way
check_for_params_file
source $PARAMS_FILE

# set FORWARD_SCRIPT and FOUND
set_forward_script
check_previous_submit
# Set up the destination directory on the resourceand upload the sbatch script
echo
echo "== Getting destination directory =="
RESOURCE_HOME=`ssh ${RESOURCE} pwd`
ssh ${RESOURCE} mkdir -p $RESOURCE_HOME/forward-util
echo
echo "== Uploading sbatch script =="
scp $FORWARD_SCRIPT ${RESOURCE}:$RESOURCE_HOME/forward-util/
# Adjust the partition if necessary
set_partition
echo
# Submit the sbatch job
echo "== Submitting sbatch =="
# Check whether the job includes a GPU
if [ -z "$GPUS" ]
then
    GPU_REQUEST=""
else
    GPU_REQUEST="--gpus=$GPUS"
fi
# Check whether job contains contrainsts on which GPUs to use
# Set default value for GPUS constraint if not defined
: ${CONSTRAINT_H100:=0}
: ${CONSTRAINT_A100:=0}
if [ "$CONSTRAINT_H100" -eq 1 ]
then
    echo "GPU constrained to H100"
    GPU_CONSTRAINT="--constraint=GPU_SKU:H100_SXM5"
elif [ "$CONSTRAINT_A100" -eq 1 ]
then
    echo "GPU constrained to A100"
    GPU_CONSTRAINT="--nodelist=sh03-18n07"
fi
# Write command to submit the sbatch job on the resource
command="sbatch
    --job-name=$NAME --partition=$PARTITION
    --ntasks=$CORES $GPU_REQUEST $GPU_CONSTRAINT $ADDITIONAL_ARGS
    --nodes=1
    --output=$RESOURCE_HOME/forward-util/$SBATCH_NAME.out
    --error=$RESOURCE_HOME/forward-util/$SBATCH_NAME.err
    --mem=$MEM
    --time=$TIME
    $RESOURCE_HOME/forward-util/$SBATCH_NAME $PORT \"${@:2}\""
# Submit the sbatch job on the resource
echo ${command}
ssh ${RESOURCE} ${command}
# Tell the user how to debug before trying
instruction_get_logs
# Wait for the node allocation, get identifier
get_machine
echo "notebook running on $MACHINE"
# Set up port forwarding
setup_port_forwarding
# Wait for the notebook to start
sleep 10
echo "== Connecting to notebook =="
# Print logs for the user, in case needed
print_logs
echo
# Print logs for the user, in case needed
instruction_get_logs
echo
echo "== Instructions =="
echo "1. Password, output, and error printed to this terminal? Look at logs (see instruction above)"
echo "2. Browser: http://sh-02-21.int:$PORT/ -> http://localhost:$PORT/..."
echo "3. To end session: bash end.sh ${NAME}"
