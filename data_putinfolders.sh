#!/bin/bash

#####
# "Clean" up pre-processed data, i.e. re-organize
#####

study=$1
subject=$2
input=~/Desktop/AnalysisInProgress/${subject}
processed_folder=${input}/processed/t1

if [ ! -d "${processed_folder}/transforms" ] ; then
  mkdir -p ${processed_folder}/transforms
fi

mv ${processed_folder}/sa2rage_2_mp2rage.mat ${processed_folder}/transforms/sa2rage_2_mp2rage.mat
mv ${processed_folder}/mp2rage_2_acpc.mat ${processed_folder}/transforms/mp2rage_2_acpc.mat

if [ ! -d "${processed_folder}/transforms/ACPC" ] ; then
  mkdir -p ${processed_folder}/transforms/ACPC
fi

mv ${processed_folder}/roi2full.mat ${processed_folder}/transforms/ACPC/roi2full.mat
mv ${processed_folder}/full2roi.mat ${processed_folder}/transforms/ACPC/full2roi.mat
mv ${processed_folder}/robustroi.nii.gz ${processed_folder}/transforms/ACPC/robustroi.nii.gz
mv ${processed_folder}/acpc_final.nii.gz ${processed_folder}/transforms/ACPC/acpc_final.nii.gz
mv ${processed_folder}/roi2std.mat ${processed_folder}/transforms/ACPC/roi2std.mat
mv ${processed_folder}/full2std.mat ${processed_folder}/transforms/ACPC/full2std.mat

if [ ! -d "${processed_folder}/brainmask" ] ; then
  mkdir -p ${processed_folder}/brainmask
fi

mv ${processed_folder}/brain_mask.nii.gz ${processed_folder}/brainmask/brain_mask.nii.gz
mv ${processed_folder}/dura.nii.gz ${processed_folder}/brainmask/dura.nii.gz
mv ${processed_folder}/arteries.nii.gz ${processed_folder}/brainmask/arteries.nii.gz
mv ${processed_folder}/dura_mask.nii.gz ${processed_folder}/brainmask/dura_mask.nii.gz
mv ${processed_folder}/arteries_mask.nii.gz ${processed_folder}/brainmask/arteries_mask.nii.gz
mv ${processed_folder}/csf_mask.nii.gz ${processed_folder}/brainmask/csf_mask.nii.gz
mv ${processed_folder}/brain_mask_no_arteries.nii.gz ${processed_folder}/brainmask/brain_mask_no_arteries.nii.gz
mv ${processed_folder}/bg.nii.gz ${processed_folder}/brainmask/bg.nii.gz
mv ${processed_folder}/bg_mask.nii.gz ${processed_folder}/brainmask/bg_mask.nii.gz
mv ${processed_folder}/brain_mask_filtered.nii.gz ${processed_folder}/brainmask/brain_mask_filtered.nii.gz

if [ ! -d "${processed_folder}/intermediates" ] ; then
  mkdir -p ${processed_folder}/intermediates
fi

mv ${processed_folder}/b1map.nii.gz ${processed_folder}/intermediates/b1map.nii.gz
mv ${processed_folder}/mp2rage_inv2.nii.gz ${processed_folder}/intermediates/mp2rage_inv2.nii.gz
mv ${processed_folder}/mp2rage_corr.nii.gz ${processed_folder}/intermediates/mp2rage_corr.nii.gz
mv ${processed_folder}/t1_corr.nii.gz ${processed_folder}/intermediates/t1_corr.nii.gz
mv ${processed_folder}/mp2rage_brain.nii.gz ${processed_folder}/intermediates/mp2rage_brain.nii.gz
mv ${processed_folder}/t1_mp2rage.nii.gz ${processed_folder}/intermediates/t1_mp2rage.nii.gz
mv ${processed_folder}/t1_mp2rage_gdc.nii.gz ${processed_folder}/intermediates/t1_mp2rage_gdc.nii.gz
mv ${processed_folder}/mp2rage_brain_gdc.nii.gz ${processed_folder}/intermediates/mp2rage_brain_gdc.nii.gz

if [ ! -d "${processed_folder}/finals" ] ; then
  mkdir -p ${processed_folder}/finals
fi

mv ${processed_folder}/t1_mp2rage_final.nii.gz ${processed_folder}/finals/t1_mp2rage_final.nii.gz
mv ${processed_folder}/mp2rage_brain_final.nii.gz ${processed_folder}/finals/mp2rage_brain_final.nii.gz
