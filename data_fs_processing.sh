#!/bin/bash

# Run FS pipeline

# Set-up variables
study=$1
subject=$2
n_cores=$3
SUBJECTS_DIR=~/Desktop/Freesurfer/${study}
input=~/Desktop/AnalysisInProgress/${study}/${subject}
mri_folder=${SUBJECTS_DIR}/${subject}/mri
surf_folder=${SUBJECTS_DIR}/${subject}/surf
scripts_folder=${SUBJECTS_DIR}/${subject}/scripts
expert=~/Desktop/Scripts/expert.opts

if [ ! -d ${SUBJECTS_DIR} ] ; then
  mkdir -p ${SUBJECTS_DIR} 
fi

# Input volumes (T1w and T1, i.e. fake T2w...)
T1winput=${input}/processed/t1/finals/mp2rage_brain_final.nii.gz
T1input=${input}/processed/t1/finals/t1_mp2rage_final.nii.gz

# Generate FreeSurfer folder for subject
echo "--------------------------------------------------------------------------------------------------------"
echo "Running FreeSurfer analysis for ${subject}, will take a while..."
echo "--------------------------------------------------------------------------------------------------------"
recon-all -i $T1winput -subjid ${subject}

# Make input volume compatible for FreeSurfer pipeline
mri_convert $T1input ${mri_folder}/t1_mp2rage.mgz --conform_min
mri_convert ${mri_folder}/orig/001.mgz ${mri_folder}/orig.mgz --conform_min
cp ${mri_folder}/orig.mgz ${mri_folder}/rawavg.mgz

mri_add_xform_to_header -c ${mri_folder}/transforms/talairach.xfm ${mri_folder}/orig.mgz ${mri_folder}/orig.mgz
mri_add_xform_to_header -c ${mri_folder}/transforms/talairach.xfm ${mri_folder}/t1_mp2rage.mgz ${mri_folder}/t1_mp2rage.mgz

# Initial Recon-all Steps
recon-all -subjid ${subject} -talairach -nuintensitycor -normalization \
	-hires -expert $expert -parallel -openmp ${n_cores} -use-gpu

# Generate brain mask
mri_convert ${mri_folder}/T1.mgz ${mri_folder}/brainmask.mgz
mri_em_register_cuda -mask ${mri_folder}/brainmask.mgz ${mri_folder}/nu.mgz \
	$FREESURFER_HOME/average/RB_all_2008-03-26.gca ${mri_folder}/transforms/talairach_with_skull.lta

recon-all -subjid ${subject} -skullstrip -clean-bm -no-wsgcaatlas \
	-hires -parallel -openmp ${n_cores} -use-gpu

# Call recon-all to run "-autorecon2" stage
recon-all -subjid ${subject} -autorecon2 \
	-hires -parallel -openmp ${n_cores} -use-gpu

# Backup first "mris_make_surfaces" pass output
cp ${surf_folder}/lh.pial ${surf_folder}/lh.woT2.pial
cp ${surf_folder}/rh.pial ${surf_folder}/rh.woT2.pial

cp ${surf_folder}/lh.thickness ${surf_folder}/lh.woT2.thickness
cp ${surf_folder}/rh.thickness ${surf_folder}/rh.woT2.thickness

# Intermediate recon-all steps. Inflation to sphere runs serials as parallel consumes to much memory..
recon-all -subjid ${subject} -sphere -hires -openmp ${n_cores} -use-gpu
recon-all -subjid ${subject} -surfreg -jacobian_white -avgcurv -cortparc -hires -parallel -openmp ${n_cores} -use-gpu

# Normalize T1 input volume using wm mask
mri_convert ${mri_folder}/t1_mp2rage.mgz ${mri_folder}/t1_mp2rage_tmp.nii.gz
mri_convert ${mri_folder}/wm.mgz ${mri_folder}/wm.nii.gz
fslmaths ${mri_folder}/wm.nii.gz -bin ${mri_folder}/wm.nii.gz
wmMeanT2=`fsl5.0-fslstats ${mri_folder}/t1_mp2rage_tmp.nii.gz -k ${mri_folder}/wm.nii.gz -M`
fsl5.0-fslmaths ${mri_folder}/t1_mp2rage_tmp.nii.gz -div $wmMeanT2 -mul 57 ${mri_folder}/t1_mp2rage_tmp.nii.gz -odt float
mri_convert ${mri_folder}/t1_mp2rage_tmp.nii.gz ${mri_folder}/t1_mp2rage.mgz
rm ${mri_folder}/t1_mp2rage_tmp.nii.gz

# Write additional parameters for second pass of "mris_make_surfaces" to expert file 
echo "mris_make_surfaces -white NOWRITE -nsigma_above 2 -nsigma_below 3 -orig_pial woT2.pial -T1 brain.finalsurfs -T2 ${mri_folder}/t1_mp2rage" >> ${scripts_folder}/expert-options

# Run second pass "mris_make_surfaces" with T1 volume to optimize pial surface placement
recon-all -subjid ${subject} -pial \
	-hires -parallel -openmp ${n_cores} -use-gpu

cp ${surf_folder}/lh.white.preaparc ${surf_folder}/lh.white
cp ${surf_folder}/rh.white.preaparc ${surf_folder}/rh.white

# Don't know why exactly, but have to manually re-compute cortical thickness maps using new pial surface
mris_thickness ${subject} lh lh.wT2.thickness
mris_thickness ${subject} rh rh.wT2.thickness

# Final recon-all steps
recon-all -subjid ${subject} -cortribbon -parcstats -cortparc2 -parcstats2 -cortparc3 -parcstats3 -pctsurfcon \
	-hyporelabel -aparc2aseg -apas2aseg -segstats -wmparc -balabels \
	-hires -parallel -openmp ${n_cores} -use-gpu

echo "--------------------------------------------------------------------------------------------------------"
echo "FreeSurfer analysis for ${subject} done..."
echo "--------------------------------------------------------------------------------------------------------"
