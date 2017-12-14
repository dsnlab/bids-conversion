#!/bin/bash

cd /projects/dsnlab/shared/tag/bids_data/

for sub in sub-TAG*; do

cd $sub
pwd

rm ses-wave?/anat/*json

cd ../

done

