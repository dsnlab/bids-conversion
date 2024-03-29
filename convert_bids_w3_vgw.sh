#!/bin/bash +x

# This script will convert dicoms, create the BIDS files structure,
# and move and rename converted files to BIDS specification
#
# It will also check the number of files and print errors to the error log
#

#VGW ran this code from her own directory; 
#if you are trying to run this on the DSN lab shared folder/directory,
#you will likely need to adjust the paths to pull the correct data


# DEPENDENCIES: All of these variables are set by the outer
# batch conversion script (called batch_convert_bids_w3_vgw.sh at the time of writing). 
for varname in sessid subid dicomdir outdir config scriptsdir
do
  if [ -z "${!varname+SET}" ]
  then
    echo "ERROR: \$$varname not set!" >&2
    echo "(Are you running this standalone? \`$0' is meant to be called from a sbatch wrapper script -- \`batch_$0')" >&2
  fi
done

# Load mcverter and other software
module load MRIConvert 
module load python3
module load dcmtk

# Load variables
source "$config"
echo "${subid}"_"${sessid}"

# Create error log file
touch "${errorlog}"

# Check directory dependencies
mkdir -p "${archivedir}" 	"${niidir}" 	"${bidsdir}" 	"${bidsdir}"/derivatives

# Convert dicoms to niftis
echo -e "\nCreating nii directory"

mkdir -pv "$niidir"

mkdir -pv "${subid}"/"${sessid}"

cd "$niidir"/"${subid}"/"${sessid}"
if [ "${convertanat}" == "TRUE" ] && [ ! "$(ls -A anat)" ]; then
	echo -e "\nConverting anatomical mprage into nifti"
	mkdir anat
	anatomicaloutput="$niidir/${subid}/${sessid}/anat"
	mcverter -o "${anatomicaloutput}"/ --format=nifti --nii --match="${anat}" -F -PatientName-PatientId-SeriesDate-SeriesTime-StudyId-StudyDescription+SeriesNumber-SequenceName-ProtocolName+SeriesDescription $dicomdir
	cd "${anatomicaloutput}"
	du -sh *.nii
	gzip -f *.nii
	cd "$niidir"/"${subid}"/"${sessid}"
else
	anatomicaloutput="$niidir/${subid}/${sessid}/anat"
fi

if [ "${convertfmap}" == "TRUE" ] && [ ! "$(ls -A fmap)" ]; then
	echo -e "\nConverting fieldmaps into niftis"
	cd "$niidir"/"${subid}"/"${sessid}"
	mkdir fmap
	fmapoutput="$niidir/${subid}/${sessid}/fmap"
	mcverter -o "${fmapoutput}"/ --format=nifti --nii --match="${fmap}" -F -PatientName-PatientId-SeriesDate-SeriesTime-StudyId-StudyDescription+SeriesNumber-SequenceName-ProtocolName+SeriesDescription $dicomdir
	cd "${fmapoutput}"
	du -sh *.nii
	gzip -f *.nii
	cd "$niidir"/"${subid}"/"${sessid}"
else
	fmapoutput="$niidir/${subid}/${sessid}/fmap"
fi

if [ "${convertdti}" == "TRUE" ] && [ ! "$(ls -A dti)" ]; then
	echo -e "\nConverting DTI into 4D nifti"
	cd "$niidir"/"${subid}"/"${sessid}"
	mkdir dti
	dtioutput="$niidir/${subid}/${sessid}/dti"
	mcverter -o "${dtioutput}"/ --format=nifti --nii --fourd --match="${dti}" -F -PatientName-PatientId-SeriesDate-SeriesTime-StudyId-StudyDescription+SeriesNumber-SequenceName-ProtocolName+SeriesDescription $dicomdir
	cd "${dtioutput}"
	du -sh *.nii
	gzip -f *.nii
	cd "$niidir"/"${subid}"/"${sessid}"
else
	dtioutput="$niidir/${subid}/${sessid}/dti"
fi

if [ "${convertrest}" == "TRUE" ] && [ ! "$(ls -A resting)" ]; then
	echo -e "\nConverting resting state into 4D niftis"
	cd "$niidir"/"${subid}"/"${sessid}"
	mkdir -p resting
	restingoutput="$niidir/${subid}/${sessid}/resting"
	for rest in ${resting[@]}; do 
		mcverter -o "${restingoutput}"/ --format=nifti --nii --fourd --match="${rest}" -F -PatientName-PatientId-SeriesDate-SeriesTime-StudyId-StudyDescription+SeriesNumber-SequenceName-ProtocolName+SeriesDescription $dicomdir
	done
	cd "${restingoutput}"
	du -sh *.nii
	gzip -f *.nii
	cd "$niidir"/"${subid}"/"${sessid}"
else
	restingoutput="$niidir/${subid}/${sessid}/resting"
fi

if [ "${converttask}" == "TRUE" ] && [ ! "$(ls -A task)" ]; then
	echo -e "\nConverting fMRI task data into 4D niftis"
	cd "$niidir"/"${subid}"/"${sessid}"
        mkdir -p task
	taskoutput="$niidir/${subid}/${sessid}/task"
	for task in ${tasks[@]}; do
		mcverter -o "${taskoutput}"/ --format=nifti --nii --fourd --match=${task} -F -PatientName-PatientId-SeriesDate-SeriesTime-StudyId-StudyDescription+SeriesNumber-SequenceName-ProtocolName+SeriesDescription $dicomdir
	done
	cd "${taskoutput}"
	du -sh *.nii
	gzip -f *.nii
	cd "$niidir"/"${subid}"/"${sessid}"
else
	taskoutput="$niidir/${subid}/${sessid}/task"
fi


# Run python script to extract Multiband Acceleration Factor
echo -e "\nCreating text file with additionl acquisition info"
python $scriptsdir/extract_dicom_fields.py "$dicomdir" "$niidir"/"${subid}"/"${sessid}"/"${subid}"_"${sessid}"_multiband_accel.txt PatientName StudyDate SeriesNumber SeriesDescription ImageComments -a -n

# Copy group meta-data to bids directory
rsync -aiv $scriptsdir/meta_data/ $bidsdir/

# Create bids directory structure for one subject
echo -e "\nCreating BIDS directory stucture..."
mkdir -pv "$bidsdir"/sub-"${subid}"/ses-"${sessid}"
cd "$bidsdir"/sub-"${subid}"/ses-"${sessid}"
if [ "${convertanat}" == "TRUE" ]; then mkdir -pv anat; fi
if [ "${convertfmap}" == "TRUE" ]; then mkdir -pv fmap; fi
if [ "${convertdti}" == "TRUE" ]; then mkdir -pv dwi; fi
if [ "${converttask}" == "TRUE" ]; then mkdir -pv func; fi

# Copy and rename files to BIDS structure
# structural (mprage)
if [ "${convertanat}" == "TRUE" ]; then
	echo -e "\nCopying structural"
	if [ $(ls "${anatomicaloutput}"/*"${anat}".nii.gz | wc -l) -eq 1 ]; then
		cp ${cpflags} "${anatomicaloutput}"/*"${anat}".nii.gz "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/anat/sub-"${subid}"_ses-"${sessid}"_T1w.nii.gz
	elif [ $(ls "${anatomicaloutput}"/*"${anat}".nii.gz | wc -l) -eq 0 ]; then
		# print missing file paths in errorlog.txt if = 0 files
		echo "ERROR: no files; nothing to copy"
		echo "${anatomicaloutput}": MISSING "${anat}" >> $errorlog
	else 
		# print file paths in errorlog.txt if =~ 1 file; copy both files
		echo "ERROR: wrong number of files; file with highest sequence number copied"
		ls "${anatomicaloutput}"/*"${anat}".nii.gz >> $errorlog
		
		#Uncomment the commented lines if you have repeated mprages and would like them to be saved in the bidsbir.
		#For now, the script does not do this as we only re-do mprages if one is really bad quality - and I don't think the poor image 
		#should be copied to bidsdir and used by bidsapps
		#The script now copies the T1w scan with the highest sequence number, so the second one if the sequence was repeated (edited by MEAB on 11/11/2019)

		#t1r1=$(ls "${anatomicaloutput}"/*"${anat}".nii.gz | head -1)
		t1r2=$(ls "${anatomicaloutput}"/*"${anat}".nii.gz | tail -1)
		#cp ${cpflags} "${t1w1}" "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/anat/sub-"${subid}"_ses-"${sessid}"_run-01_T1w.nii.gz
		cp ${cpflags} "${t1r2}" "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/anat/sub-"${subid}"_ses-"${sessid}"_T1w.nii.gz
	fi
fi

# fieldmaps
if [ "${convertfmap}" == "TRUE" ]; then
	echo -e "\nCopying fieldmaps"
	if [ $(ls "${fmapoutput}"/*"${fmap}"*.gz | wc -l) -eq 0 ]; then
		# print missing file paths in errorlog.txt if = 0 files
		echo "ERROR: no files; nothing to copy"
		echo "${fmapoutput}": MISSING "${fmap}" >> $errorlog
	elif [ "${fieldmapEPI}" == "TRUE" ]; then
		ap=$(ls -f "${fmapoutput}"/*_ap.nii.gz | head -1)
		pa=$(ls -f "${fmapoutput}"/*_pa.nii.gz | head -1)
		cp ${cpflags} "${ap}"  "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/fmap/sub-"${subid}"_ses-"${sessid}"_dir-ap_epi.nii.gz
		cp ${cpflags} "${pa}"  "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/fmap/sub-"${subid}"_ses-"${sessid}"_dir-pa_epi.nii.gz
		
		# print file paths in errorlog.txt if =~ 2 files
		if [ $(ls "${fmapoutput}"/*_ap.nii.gz | wc -l) -ne 2 ]; then
			echo "ERROR: wrong number of files"
			ls "${fmapoutput}"/*_ap.nii.gz >> $errorlog
		fi
	else
		phase=$(ls -f "${fmapoutput}"/*"${fmap}".nii.gz)
		mag1=$(ls -f "${fmapoutput}"/*"${fmap}"_01.nii.gz)
		mag2=$(ls -f "${fmapoutput}"/*"${fmap}"_02.nii.gz)
		cp ${cpflags} "${phase}"  "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/fmap/sub-"${subid}"_ses-"${sessid}"_phasediff.nii.gz
		cp ${cpflags} "${mag1}"  "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/fmap/sub-"${subid}"_ses-"${sessid}"_magnitude1.nii.gz
		cp ${cpflags} "${mag2}"  "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/fmap/sub-"${subid}"_ses-"${sessid}"_magnitude2.nii.gz

		# print file paths in errorlog.txt if =~ 3 files
		if [ $(ls "${fmapoutput}"/*"${fmap}"*.gz | wc -l) -ne 3 ]; then
			echo "ERROR: wrong number of files"
			ls "${fmapoutput}"/*"${fmap}"*.gz >> $errorlog
		fi
	fi
fi

# DTI 
if [ "${convertdti}" == "TRUE" ]; then
	echo -e "\nCopying DTI"
	if [ $(ls "${dtioutput}"/*"${dti}"*.nii.gz | wc -l) -eq 2 ]; then
		cp ${cpflags} "${dtioutput}"/*"${dti}"*rl.nii.gz "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/dwi/sub-"${subid}"_ses-"${sessid}"_acq-rl_dwi.nii.gz
		cp ${cpflags} "${dtioutput}"/*"${dti}"*lr.nii.gz "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/dwi/sub-"${subid}"_ses-"${sessid}"_acq-lr_dwi.nii.gz
		cp ${cpflags} "${dtioutput}"/*"${dti}"*rl_bvecs "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/dwi/sub-"${subid}"_ses-"${sessid}"_acq-rl_dwi_bvecs
		cp ${cpflags} "${dtioutput}"/*"${dti}"*rl_bvals "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/dwi/sub-"${subid}"_ses-"${sessid}"_acq-rl_dwi_bvals
		cp ${cpflags} "${dtioutput}"/*"${dti}"*lr_bvecs "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/dwi/sub-"${subid}"_ses-"${sessid}"_acq-lr_dwi_bvecs
		cp ${cpflags} "${dtioutput}"/*"${dti}"*lr_bvals "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/dwi/sub-"${subid}"_ses-"${sessid}"_acq-lr_dwi_bvals
	elif [ $(ls "${dtioutput}"/*"${dti}"*.nii.gz | wc -l) -eq 0 ]; then
		# print missing file paths in errorlog.txt if = 0 files
		echo "ERROR: no files; nothing to copy"
		echo "${dtioutput}": MISSING "${dti}" >> $errorlog
	else
		# print file paths in errorlog.txt if =~ 2 files; do not copy file
		echo "ERROR: wrong number of files; files not copied"
		ls "${dtioutput}"/*"${dti}"*.nii.gz >> $errorlog
	fi
fi

# resting state 
if [ "${convertrest}" == "TRUE" ]; then
	echo -e "\nCopying resting state"
	for rest in ${resting[@]}; do 
		if [ $(ls "${restingoutput}"/*"${rest}".nii.gz | wc -l) -eq 1 ]; then
			runnum="$(echo "${rest}" | tail -c 2)"
			cp ${cpflags} "${restingoutput}"/*"${rest}".nii.gz  "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/func/sub-"${subid}"_ses-"${sessid}"_task-rest_run-0"${runnum}"_bold.nii.gz
		elif [ $(ls "${restingoutput}"/*"${rest}".nii.gz  | wc -l) -eq 0 ]; then
			# print missing file paths in errorlog.txt if = 0 files
			echo "ERROR: no "${rest}" files; nothing to copy"
			echo "${restingoutput}": MISSING "${rest}" >> $errorlog
		else
			# print file paths in errorlog.txt if =~ 1 files; do not copy file
			echo "ERROR: wrong number of "${rest}" files; files not copied"
			ls "${restingoutput}"/*"${rest}".nii.gz >> $errorlog
		fi
	done
fi

# fMRI task data
if [ "${converttask}" == "TRUE" ]; then
	echo -e "\nCopying task fMRI"
	for task in ${tasks[@]}; do 
		runnum="$(echo "${task}" | sed 's/[^0-9]//g')"
		taskalpha="$(echo "${task}" | sed 's/[^a-zA-Z]//g')"
		if [ $(ls "${taskoutput}"/*"${task}"*.nii.gz | wc -l) -eq 1 ]; then
			if [[ $runnum =~ ^[0-9]+$ ]]; then 
				cp ${cpflags} "${taskoutput}"/*"${task}"*.nii.gz "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/func/sub-"${subid}"_ses-"${sessid}"_task-"${taskalpha}"_run-0"${runnum}"_bold.nii.gz
			else
				cp ${cpflags} "${taskoutput}"/*"${task}"*.nii.gz "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/func/sub-"${subid}"_ses-"${sessid}"_task-"${taskalpha}"_run-01_bold.nii.gz
			fi
		elif [ $(ls "${taskoutput}"/*"${task}"*.nii.gz | wc -l) -eq 0 ]; then
			# print missing file paths in errorlog.txt if = 0 files
			echo "ERROR: no "${task}" files; nothing to copy"
			echo "${taskoutput}": MISSING "${task}" >> $errorlog
		else
			# print file paths in errorlog.txt if =~ 1 files; copy the largest file
			echo "ERROR: wrong number of "${task}" files; largest file copied"
			ls "${taskoutput}"/*"${task}"*.nii.gz >> $errorlog
			largestfile=$(du -sh "${taskoutput}"/*"${task}"*.nii.gz | sort -n | tail -1 | cut -f2)
			if [[ $runnum =~ ^[0-9]+$ ]]; then 
				cp ${cpflags} "${largestfile}" "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/func/sub-"${subid}"_ses-"${sessid}"_task-"${taskalpha}"_run-0"${runnum}"_bold.nii.gz
			else
				cp ${cpflags} "${largestfile}" "$bidsdir"/sub-"${subid}"/ses-"${sessid}"/func/sub-"${subid}"_ses-"${sessid}"_task-"${taskalpha}"_run-01_bold.nii.gz
			fi
		fi
	done
fi

echo -e "\nCOMPLETED"
