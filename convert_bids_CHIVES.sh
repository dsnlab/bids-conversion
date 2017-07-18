#!/bin/bash
#
# This script will convert your directory structure
# with already dicom mcverted images (gzipped niftis)
# to BIDS specification - TC
#

# Load mcverter
module load MRIConvert

# Set folder names
echo "${dicomsubid}"
dicomdir=$(echo "/projects/sanlab/CHIVES/archive/DICOMS/${dicomsubid}"*)
inputdir="/projects/sanlab/CHIVES/archive/clean_nii"
outputdir="/projects/sanlab/CHIVES/bids_data"

# Set study info
studyid="CHIVES"
sessid="wave1"
subid="$(echo $dicomsubid | head -c 10)"
cpflags="-n -v"
declare -a tasks=("words" "money" "picture") 

# echo -e "\nConverting anatomical mprage into nifti"
# cd "$inputdir"
# mkdir "${subid}"
# cd "$inputdir"/"${subid}"
# mkdir anat
# anatomicaloutput="$inputdir/${subid}/anat"
# mcverter -o "$anatomicaloutput"/ --format=nifti --nii --match=mprage -F -PatientName-PatientId-SeriesDate-SeriesTime-StudyId-StudyDescription-SeriesNumber-SequenceName-ProtocolName+SeriesDescription $dicomdir
# cd "$inputdir"/"${subid}"/anat
# gzip -f *.nii

# echo -e "\nConverting fieldmaps into niftis"
# cd "$inputdir"/"${subid}"
# mkdir fmap
# fmapoutput="$inputdir/${subid}/fmap"
# mcverter -o "$fmapoutput"/ --format=nifti --nii --match=fieldmap -F -PatientName-PatientId-SeriesDate-SeriesTime-StudyId-StudyDescription+SeriesNumber-SequenceName-ProtocolName+SeriesDescription $dicomdir
# cd "$inputdir"/"${subid}"/fmap
# gzip -f *.nii

# echo -e "\nConverting fMRI task data into 4D niftis"
# cd "$inputdir"/"${subid}"
# mkdir task
# taskoutput="$inputdir/${subid}/task"
# for task in ${tasks[@]}
# 	do
# 	mcverter -o "$taskoutput"/ --format=nifti --nii --fourd --match=${task} -F -PatientName-PatientId-SeriesDate-SeriesTime-StudyId-StudyDescription+SeriesNumber-SequenceName-ProtocolName+SeriesDescription $dicomdir
# done
# cd "$inputdir"/"${subid}"/task
# gzip -f *.nii
# cd "$inputdir"

# create directory structure for one subject
echo -e "\nCreating directory stucture"
mkdir -pv "$outputdir"/sub-"${subid}"/ses-"${sessid}"
cd "$outputdir"/sub-"${subid}"/ses-"${sessid}"
mkdir -v anat
mkdir -v func
mkdir -v fmap

# move files and generate corresponding jsons

# structural (mprage)
echo -e "\nCopying structural"
cp ${cpflags} "$inputdir"/"${subid}"/anat/mprage.nii.gz "$outputdir"/sub-"${subid}"/ses-"${sessid}"/anat/sub-"${subid}"_ses-"${sessid}"_T1w.nii.gz
#cp ${cpflags} "$inputdir"/CHIVESanat.json "$outputdir"/sub-"${subid}"/ses-"${sessid}"/anat/sub-"${subid}"_ses-"${sessid}"_T1w.json

# fieldmaps
echo -e "\nCopying fieldmaps"
ap=$(ls -f "$inputdir"/"${subid}"/fmap/*_ap.nii.gz | head -1)
cp ${cpflags} "${ap}"  "$outputdir"/sub-"${subid}"/ses-"${sessid}"/fmap/sub-"${subid}"_ses-"${sessid}"_dir-ap_epi.nii.gz
pa=$(ls -f "$inputdir"/"${subid}"/fmap/*_pa.nii.gz | head -1)
cp ${cpflags} "${pa}"  "$outputdir"/sub-"${subid}"/ses-"${sessid}"/fmap/sub-"${subid}"_ses-"${sessid}"_dir-pa_epi.nii.gz
# cp ${cpflags} "$inputdir"/CHIVESfmap.json "$outputdir"/sub-"${subid}"/ses-"${sessid}"/fmap/sub-"${subid}"_ses-"${sessid}"_dir-pa_epi.json
# cp ${cpflags} "$inputdir"/CHIVESfmap.json "$outputdir"/sub-"${subid}"/ses-"${sessid}"/fmap/sub-"${subid}"_ses-"${sessid}"_dir-pa_epi.json

# fMRI task data 
echo -e "\nCopying task fMRI"
for task in ${tasks[@]}
	do 
	for run in $(ls -f "$inputdir"/"${subid}"/task/*"${task}"*.nii.gz)
		do
		runnum="$(ls $run | tail -c 9 | head -c 1)"
		if [[ $runnum =~ ^[0-9]+$ ]]
			then 
			cp ${cpflags} "${run}"  "$outputdir"/sub-"${subid}"/ses-"${sessid}"/func/sub-"${subid}"_ses-"${sessid}"_task-"${task}"_run-0"${runnum}"_bold.nii.gz
		else
			cp ${cpflags} "${run}"  "$outputdir"/sub-"${subid}"/ses-"${sessid}"/func/sub-"${subid}"_ses-"${sessid}"_task-"${task}"_run-01_bold.nii.gz
		fi
		#cp -v "$inputdir"/CHIVEStask.json "$outputdir"/sub-"${subid}"/ses-"${sessid}"/func/sub-"${subid}"_ses-"${sessid}"_task-"${task}"_run-0"${runnum}"_bold.json
	done
done

# make derivatives folder
cd "${outputdir}"
mkdir derivatives





