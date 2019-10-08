#!/bin/bash

PORT=$1
NOTEBOOK_DIR=$2
cd $NOTEBOOK_DIR

module load system
module load x11
module load stata
/home/groups/maggiori/miniconda3/bin/conda init bash
source ~/.bashrc

source activate gcap
jupyter lab --no-browser --port=$PORT
