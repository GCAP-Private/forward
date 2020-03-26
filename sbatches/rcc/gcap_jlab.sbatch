#!/bin/bash

PORT=$1
NOTEBOOK_DIR=$2
cd $NOTEBOOK_DIR

module load stata/15
module load Anaconda3
source ~/.bashrc
conda init bash
source ~/.bashrc
conda activate /project2/neiman/GCAP/software/python/gcap

# TODO: Make scratch folder and link here
# STATATMP="/scratch/midway2/neiman/stata_tmp"
# export STATATMP

/project2/neiman/GCAP/software/python/gcap/bin/jupyter lab --no-browser --port=$PORT
