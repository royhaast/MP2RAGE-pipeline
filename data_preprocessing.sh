#!/bin/bash

#####
# High-res analysis pipeline for MP2RAGE data, losely based on HCP's
# anatomical pipeline.
#
# Software requirements:
# 	- FSL (latest release)
#	- ANTs (latest release)
#	- CBS tools (including MIPAV and JIST, latest releases)
#	- B1 correction code from J.P. Marques (and MATLAB)
#	- FreeSurfer v6.0 (stable)
#
# Tested on Linux system with:
#	- 32 gb RAM
#	- 16 cores
#	- CUDA v5.0 installed
#	- Debian Wheezy (necessary for CUDA support)
#
# R.A.M. Haast (2017)
#####

# Set-up MIPAV command line environment
mipavjava="/home/roy/mipav/jre/bin/java -classpath /home/roy/mipav/plugins/:/home/roy/mipav/:`find /home/roy/mipav/ -name \*.jar | sed 's#/home/roy/mipav/#:/home/roy/mipav/#' | tr -d '\n' | sed 's/^://'`"

# Set-up variables
study=$1
subject=$2
input=~/Desktop/AnalysisInProgress/${subject}
processed_folder=${input}/processed/t1
progressfile=${input}/${subject}_progress.txt
scripts_folder=~/Desktop/Scripts
mni_brain=${scripts_folder}/MNI152_T1_0.7mm_brain.nii.gz
downsample="0"

if [ ! -d "${processed_folder}" ] ; then
  mkdir -p ${processed_folder}
fi

# Input volumes
mp2rage="${input}/niftis/t1/*mp2rage*UNI_Images.nii.gz"
t1="${input}/niftis/t1/*mp2rage*T1_Images.nii.gz"
mp2rage_inv2="${input}/niftis/t1/*mp2rage*INV2.nii.gz"
sa2rage_inv2="${input}/niftis/t1/*sa2rage*invContrast2.nii.gz"
sa2rage_b1map="${input}/niftis/t1/*sa2rage*B1map.nii.gz"

# Coregister B1 map to MP2RAGE data
echo "--------------------------------------------------------------------------------------------------------"
echo "Coregistering B1 map from subject ${subject} to MP2RAGE volume..."
echo "--------------------------------------------------------------------------------------------------------"
fsl5.0-flirt -verbose 1 -in ${sa2rage_inv2} -ref ${mp2rage_inv2} -omat ${processed_folder}/sa2rage_2_mp2rage.mat
fsl5.0-flirt -verbose 1 -in ${sa2rage_b1map} -ref ${mp2rage_inv2} -applyxfm -init ${processed_folder}/sa2rage_2_mp2rage.mat -out ${processed_folder}/b1map.nii.gz

if [[ -f ${processed_folder}/sa2rage_2_mp2rage.mat && -f ${processed_folder}/b1map.nii.gz ]]; then
    echo "B1 map to MP2RAGE coregistration: completed" >> ${progressfile}
fi

# Remove bias field from MP2RAGE INV2 volume to improve brain extraction
echo "--------------------------------------------------------------------------------------------------------"
echo "Removing bias field from ${subject}'s MP2RAGE INV2 volume for better brain extraction..."
echo "--------------------------------------------------------------------------------------------------------"
cd ${processed_folder}
N4BiasFieldCorrection -v -d 3 -i ${mp2rage_inv2} -s 2 -c [100x100x100x100,0.0000000001] -o mp2rage_inv2.nii.gz

if [ -f ${processed_folder}/mp2rage_inv2.nii.gz ]; then
    echo "N4BiasFieldCorrection of INV2 volume: completed" >> ${progressfile}
fi

# Perform brain extraction using CBS tools
echo "--------------------------------------------------------------------------------------------------------"
echo "Performing brain extraction..."
echo "--------------------------------------------------------------------------------------------------------"
fsl5.0-bet ${processed_folder}/mp2rage_inv2.nii.gz ${processed_folder}/brain.nii.gz -v -R -m -f 0.20 -g 0
rm brain.nii.gz

# Get probability map for the dura
${mipavjava} edu.jhu.ece.iacl.jist.cli.run de.mpg.cbs.jist.brain.JistBrainMp2rageDuraEstimation \
      -inSecond ${mp2rage_inv2} \
      -inSkull ${processed_folder}/brain_mask.nii.gz \
      -inDistance 2 \
      -inoutput dura_prior \
      -outDura ${processed_folder}/dura.nii.gz

# Get probability map for the arteries
${mipavjava} edu.jhu.ece.iacl.jist.cli.run de.mpg.cbs.jist.brain.JistBrainMp2rageArteriesFilter \
      -inT1 ${t1} \
      -inT1weighted ${mp2rage} \
      -inSecond ${mp2rage_inv2} \
      -outArteries ${processed_folder}/arteries.nii.gz

# Compute dura and arteries binary masks to exclude from brain mask 
fsl5.0-fslmaths ${processed_folder}/dura.nii.gz -thr 0.99 -uthr 1 -bin ${processed_folder}/dura_mask.nii.gz
fsl5.0-fslmaths ${processed_folder}/arteries.nii.gz -thr 0.3 -uthr 1 -bin ${processed_folder}/arteries_mask.nii.gz
fsl5.0-fslmaths ${mp2rage} -thr 350 -bin ${processed_folder}/csf_mask.nii.gz
fsl5.0-fslmaths ${processed_folder}/brain_mask.nii.gz -sub ${processed_folder}/dura_mask.nii.gz \
	-sub ${processed_folder}/arteries_mask.nii.gz ${processed_folder}/brain_mask_filtered.nii.gz

# Only arteries exclusion for T1 map and pial surface optimization
fsl5.0-fslmaths ${processed_folder}/brain_mask.nii.gz -sub ${processed_folder}/arteries_mask.nii.gz \
	${processed_folder}/brain_mask_no_arteries.nii.gz

# 
${mipavjava} edu.jhu.ece.iacl.jist.cli.run de.mpg.cbs.jist.brain.JistBrainMp2rageDuraEstimation \
      -inSecond ${mp2rage_inv2} \
      -inSkull ${processed_folder}/brain_mask_filtered.nii.gz \
      -inDistance 2 \
      -inoutput bg_prior \
      -outDura ${processed_folder}/bg.nii.gz

fsl5.0-fslmaths ${processed_folder}/bg.nii.gz -thr 0.6 -uthr 1 -bin ${processed_folder}/bg_mask.nii.gz
fsl5.0-fslmaths ${processed_folder}/brain_mask_filtered.nii.gz -sub ${processed_folder}/bg_mask.nii.gz -thr 0 -mul ${processed_folder}/csf_mask.nii.gz ${processed_folder}/brain_mask_filtered.nii.gz

if [ -f ${processed_folder}/brain_mask.nii.gz ]; then
    echo "Computing brain mask: completed" >> ${progressfile}
fi

# Perform T1 correction using MATLAB script
echo "--------------------------------------------------------------------------------------------------------"
echo "Correct T1 using B1 map..."
echo "--------------------------------------------------------------------------------------------------------"
matlab_command="matlab -nodisplay -r 'MacroForCorrectionfunc ${processed_folder}/b1map.nii.gz ${mp2rage} ${processed_folder}; exit;'"
eval $matlab_command

pigz --best ${processed_folder}/mp2rage_corr.nii ${processed_folder}/t1_corr.nii

if [[ -f ${processed_folder}/t1_corr.nii.gz && -f ${processed_folder}/mp2rage_corr.nii.gz ]]; then
    echo "MP2RAGE and T1 correction: completed" >> ${progressfile}
fi

# AC-PC alignment to unify brain orientation across subjects
echo "--------------------------------------------------------------------------------------------------------"
echo "AC-PC alignment MP2RAGE UNI, T1 volumes and brain mask" 
echo "--------------------------------------------------------------------------------------------------------"

fsl5.0-fslmaths ${processed_folder}/mp2rage_corr.nii.gz -mul ${processed_folder}/brain_mask_filtered.nii.gz ${processed_folder}/mp2rage_brain.nii.gz
fsl5.0-fslmaths ${processed_folder}/t1_corr.nii.gz -mul ${processed_folder}/brain_mask_no_arteries.nii.gz ${processed_folder}/t1_corr_std.nii.gz

# Crop the FOV
fsl5.0-fslreorient2std ${processed_folder}/mp2rage_brain.nii.gz ${processed_folder}/mp2rage_brain_std.nii.gz
fsl5.0-fslreorient2std ${processed_folder}/t1_corr_std.nii.gz ${processed_folder}/t1_corr_std.nii.gz
fsl5.0-robustfov -i ${processed_folder}/mp2rage_brain_std.nii.gz -m ${processed_folder}/roi2full.mat -r ${processed_folder}/robustroi.nii.gz -b 200

# Invert the matrix (to get full FOV to ROI)
fsl5.0-convert_xfm -omat ${processed_folder}/full2roi.mat -inverse ${processed_folder}/roi2full.mat

# Register cropped image to MNI152 (12 DOF)
fsl5.0-flirt -interp spline -in ${processed_folder}/robustroi.nii.gz -ref $mni_brain -omat ${processed_folder}/roi2std.mat \
    -out ${processed_folder}/acpc_final.nii.gz -searchrx -30 30 -searchry -30 30 -searchrz -30 30

# Concatenate matrices to get full FOV to MNI
fsl5.0-convert_xfm -omat ${processed_folder}/full2std.mat -concat ${processed_folder}/roi2std.mat ${processed_folder}/full2roi.mat

# Get a 6 DOF approximation which does the ACPC alignment (AC, ACPC line, and hemispheric plane)
fsl5.0-aff2rigid ${processed_folder}/full2std.mat ${processed_folder}/mp2rage_2_acpc.mat

# Create a resampled image (ACPC aligned) using spline interpolation
fsl5.0-applywarp --rel --interp=spline -i ${processed_folder}/mp2rage_brain_std.nii.gz -r $mni_brain --premat=${processed_folder}/mp2rage_2_acpc.mat -o ${processed_folder}/mp2rage_brain_final.nii.gz
fsl5.0-applywarp --rel --interp=spline -i ${processed_folder}/t1_corr_std.nii.gz -r $mni_brain --premat=${processed_folder}/mp2rage_2_acpc.mat -o ${processed_folder}/t1_final.nii.gz

if [[ -f ${processed_folder}/t1_brain.nii.gz && -f ${processed_folder}/mp2rage_brain.nii.gz ]]; then
    echo "AC-PC alignment: completed" >> ${progressfile}
    echo "data_preprocessing: completed" >> ${progressfile}
fi

if [ ${downsample} == "1" ] ; then
    # Downsampling volumes (optional, faster FS processing, but less favorable)
    echo "--------------------------------------------------------------------------------------------------------"
    echo "Downsampling MP2RAGE UNI, T1 volumes and brain mask" 
    echo "--------------------------------------------------------------------------------------------------------"
    T1wImage=${processed_folder}/mp2rage_brain_final
    T1Image=${processed_folder}/t1_final

    Mean=`fsl5.0-fslstats $T1wImage.nii.gz -M`
    fsl5.0-flirt -interp spline -in "$T1wImage".nii.gz -ref "$T1wImage".nii.gz -applyisoxfm 1 -out "$T1wImage"_1mm.nii.gz
    fsl5.0-applywarp --rel --interp=spline -i "$T1wImage".nii.gz -r "$T1wImage"_1mm.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1wImage"_1mm.nii.gz
    fsl5.0-fslmaths "$T1wImage"_1mm.nii.gz -div $Mean -mul 150 -abs "$T1wImage"_1mm.nii.gz
    
    Mean=`fsl5.0-fslstats $T1Image.nii.gz -M`
    fsl5.0-flirt -interp spline -in "$T1Image".nii.gz -ref "$T1Image".nii.gz -applyisoxfm 1 -out "$T1Image"_1mm.nii.gz
    fsl5.0-applywarp --rel --interp=spline -i "$T1Image" -r "$T1Image"_1mm.nii.gz --premat=$FSLDIR/etc/flirtsch/ident.mat -o "$T1Image"_1mm.nii.gz
    fsl5.0-fslmaths "$T1Image"_1mm.nii.gz -div $Mean -mul 150 -abs "$T1Image"_1mm.nii.gz
fi

