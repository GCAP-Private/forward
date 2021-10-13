#!/bin/bash

PORT=$1
NOTEBOOK_DIR=$2
cd $NOTEBOOK_DIR

module load stata/15
module load python/anaconda-2021.05
source /project2/neiman/GCAP/software/RCC_Conda_Init.sh
# source ~/.bashrc
# conda init bash
source ~/.bashrc
source activate /project2/neiman/GCAP/software/python/gcap

# STATATMP="/scratch/midway2/$USER/stata_tmp"
STATATMP="/tmp/stata_tmp"
export STATATMP
mkdir -p $STATATMP

/project2/neiman/GCAP/software/python/gcap/bin/jupyter lab --no-browser --port=$PORT
