#!/bin/bash

PORT=$1
NOTEBOOK_DIR=$2
cd $NOTEBOOK_DIR

module load system
module load x11
module load git
module load stata/16

/home/groups/maggiori/miniconda3/bin/conda init bash
source ~/.bashrc

STATATMP="/scratch/groups/maggiori/stata_tmp"
export STATATMP

source activate gcap
cd /
jupyter lab --no-browser --port=$PORT
