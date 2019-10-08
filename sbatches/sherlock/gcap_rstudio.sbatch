#!/bin/bash

PORT=$1
NOTEBOOK_DIR=$2
cd $NOTEBOOK_DIR

module load stata

source activate gcap
jupyter lab --no-browser --port=$PORT
