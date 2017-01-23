#!/bin/bash
. ${FSLDIR}/etc/fslconf/fsl.sh

# Set-up variables
study=$1
subject=$2
n_cores=$3

# Set-up locations
scripts_folder=~/Desktop/Scripts
mni_brain=${scripts_folder}/Atlases/MNI152_T1_0.7mm_brain.nii.gz
input=~/Desktop/AnalysisInProgress/${study}/${subject}
vbq_input=~/Desktop/VBQ/${study}

# For fieldmap
ASLdwell="0.00027"
rsfMRIdwell=""

# FreeSurfer
SUBJECTS_DIR=~/Desktop/Freesurfer/${study}
mri_folder=${SUBJECTS_DIR}/${subject}/mri
surf_folder=${SUBJECTS_DIR}/${subject}/surf

# Turn on/off analysis steps
mni_warping="0"
prep_for_vbq="0"
fieldmap="0"
t2s_analysis="0"
cbf_analysis="0"
	cbf_fieldmap_correction="1"

if [ ${mni_warping} == "1" ] ; then
	# Warp volume to template space (e.g. MNI or study-specific template)
        echo "--------------------------------------------------------------------------------------------------------"
        echo "Non-linear transforming (ANTs syn) MP2RAGE UNI to MNI 0.7 template" 
        echo "--------------------------------------------------------------------------------------------------------"
	out_folder=${input}/processed/t1
	T1winput=${out_folder}/finals/mp2rage_brain_final.nii.gz
	cd ${out_folder}
	${scripts_folder}/antsRegistrationSyn.sh -d 3 -f ${mni_brain} -m ${T1winput} -o ${subject}_to_MNI_ -n ${n_cores}
	cp ${subject}_to_MNI_1Warp.nii.gz ${out_folder}/transforms/naive_to_mni_warp.nii.gz
	cp ${subject}_to_MNI_1InverseWarp.nii.gz ${out_folder}/transforms/mni_to_naive_warp.nii.gz
	cp ${subject}_to_MNI_0GenericAffine.mat ${out_folder}/transforms/naive_to_mni_affine.mat

	antsApplyTransforms -d 3 -i ${T1winput} -r ${mni_brain} -n BSpline[5] \
		-t ${out_folder}/transforms/naive_to_mni_warp.nii.gz \
		-t ${out_folder}/transforms/naive_to_mni_affine.mat \
		-o ${out_folder}/finals/mp2rage_brain_final.MNI.nii.gz

	## For inverse transformation use:
	# antsApplyTransforms -d 3 -i <input> -r ${T1winput} -n BSpline[5] \
	#	-t [${out_folder}/transforms/naive_to_mni_affine.mat,1] \
	#	-t ${out_folder}/transforms/mni_to_naive_warp.nii.gz \
	#	-o <output>
fi

if [ ${prep_for_vbq} == "1" ] ; then
	if [ ! -d "${vbq_input}" ] ; then
		mkdir -p ${vbq_input}
	fi	

	mri_binarize --i ${mri_folder}/aparc+aseg.mgz --gm --o ${vbq_input}/rc1_${subject}.nii
	mri_binarize --i ${mri_folder}/aparc+aseg.mgz --wm --o ${vbq_input}/rc2_${subject}.nii
fi

# T2 star fitting (data needs to be gradient distortion corrected on server first)
if [ ${t2s_analysis} == "1" ] ; then
	echo "--------------------------------------------------------------------------------------------------------"
	echo "Processing GRE data for T2* computation" 
	echo "--------------------------------------------------------------------------------------------------------"
	in_folder=${input}/niftis/t2s
	out_folder=${input}/processed/t2s
	out_folder_t1=${input}/processed/t1

	cd ${in_folder}
	touch tmp.txt
	ls *.nii.gz > tmp.txt

	cp `sed -n '1p' tmp.txt` ${out_folder}/GRE_all_TEs_mag.nii.gz
	#cp `sed -n '2p' tmp.txt` ${out_folder}/GRE_all_TEs_pha.nii.gz
	#rm tmp.txt

	fsl5.0-fslsplit ${out_folder}/GRE_all_TEs_mag.nii.gz ${out_folder}/GRE_TE_mag_ -t
	
	cd ${out_folder} 
	if [[ ! -z $(echo `sed -n '1p' tmp.txt` | grep GRE_ASPIRE_UMPIRE) ]]; then 
		/bin/echo -e "4\n2.53\n7.03\n12.55\n20.35\nGRE_TE_mag_0000.nii.gz\nGRE_TE_mag_0001.nii.gz\nGRE_TE_mag_0002.nii.gz\nGRE_TE_mag_0003.nii.gz" \
			| ${scripts_folder}/T2fit_code/t2_fit64 0 100 qT2		
		#fit_qt2 -source ${out_folder}/GRE_all_TEs_mag.nii.gz -t2map ${out_folder}/t2s_map.nii.gz -TEs 2.53 7.03 12.55 20.35
	elif [[ ! -z $(echo `sed -n '1p' tmp.txt` | grep GRE_ASPIRE_2-1) ]]; then
		/bin/echo -e "4\n3.75\n7.50\n11.87\n19.65\nGRE_TE_mag_0000.nii.gz\nGRE_TE_mag_0001.nii.gz\nGRE_TE_mag_0002.nii.gz\nGRE_TE_mag_0003.nii.gz" \
			| ${scripts_folder}/T2fit_code/t2_fit64 0 100 qT2
		#fit_qt2 -source ${out_folder}/GRE_all_TEs_mag.nii.gz -t2map ${out_folder}/t2s_map.nii.gz -TEs 3.75 7.5 11.87 19.65
	else
		/bin/echo -e "4\n2.53\n7.03\n12.55\n20.35\nGRE_TE_mag_0000.nii.gz\nGRE_TE_mag_0001.nii.gz\nGRE_TE_mag_0002.nii.gz\nGRE_TE_mag_0003.nii.gz" \
			| ${scripts_folder}/T2fit_code/t2_fit64 0 100 qT2		
		#fit_qt2 -source ${out_folder}/GRE_all_TEs_mag.nii.gz -t2map ${out_folder}/t2s_map.nii.gz -TEs 2.53 7.03 12.55 20.35
	fi
	mri_convert qT2_T2.nii t2s_map.nii.gz 
	rm qT2_combined.nii qT2_S0.nii qT2_T2.nii GRE_TE_mag_0001.nii.gz GRE_TE_mag_0002.nii.gz GRE_TE_mag_0003.nii.gz GRE_all_TEs_mag.nii.gz

	echo "--------------------------------------------------------------------------------------------------------"
	echo "Coregister T2* to MP2RAGE data" 
	echo "--------------------------------------------------------------------------------------------------------"

	# First TE volume is used for registration to MP2RAGE INV2 volume 
	echo "Gradient distortion correction..." 
	# Gradient distortion correction 
	fsl5.0-applywarp --rel --interp=spline -i ${out_folder}/GRE_TE_mag_0000.nii.gz -r ${out_folder}/GRE_TE_mag_0000.nii.gz \
		-w ${input}/processed/t2s/transforms/gdc_warp.nii.gz -o ${out_folder}/GRE_TE_mag_0000_gdc.nii.gz
	fsl5.0-applywarp --rel --interp=spline -i ${out_folder}/t2s_map.nii.gz -r ${out_folder}/t2s_map.nii.gz \
		-w ${input}/processed/t2s/transforms/gdc_warp.nii.gz -o ${out_folder}/t2s_map_gdc.nii.gz

	echo "Course coregistration T2* to MP2RAGE data..." 
	# Initial ('course') coregistration to MP2RAGE data
	fsl5.0-flirt -dof 6 -in ${out_folder}/GRE_TE_mag_0000_gdc.nii.gz -ref ${out_folder_t1}/intermediates/mp2rage_inv2.nii.gz \
		-omat ${out_folder}/transforms/gre_to_mp2rage.mat -out ${out_folder}/GRE_TE_mag_0000_gdc_coreg.nii.gz

	# Apply to T2 star (T2s) map
	fsl5.0-flirt -interp spline -in ${out_folder}/t2s_map_gdc.nii.gz -ref ${out_folder_t1}/intermediates/mp2rage_inv2.nii.gz -applyxfm \
		-init ${out_folder}/transforms/gre_to_mp2rage.mat -out ${out_folder}/t2s_map_gdc_coreg.nii.gz

	echo "Applying ACPC alignment..." 
	# ACPC alignment
	fsl5.0-fslreorient2std ${out_folder}/GRE_TE_mag_0000_gdc_coreg.nii.gz ${out_folder}/GRE_TE_mag_0000_gdc_coreg.nii.gz
	fsl5.0-fslreorient2std ${out_folder}/t2s_map_gdc_coreg.nii.gz ${out_folder}/t2s_map_gdc_coreg.nii.gz
	fsl5.0-applywarp --rel --interp=spline -i ${out_folder}/GRE_TE_mag_0000_gdc_coreg.nii.gz -r $mni_brain --premat=${out_folder_t1}/transforms/mp2rage_2_acpc.mat \
		-o ${out_folder}/GRE_TE_mag_0000_final.nii.gz
	fsl5.0-applywarp --rel --interp=spline -i ${out_folder}/t2s_map_gdc_coreg.nii.gz -r $mni_brain --premat=${out_folder_t1}/transforms/mp2rage_2_acpc.mat -o ${out_folder}/t2s_map_final.nii.gz

	# Bring in FreeSurfer space
	mri_convert ${out_folder}/GRE_TE_mag_0000_final.nii.gz ${out_folder}/GRE_TE_mag_0000_final.mgz --conform_min -nc
	mri_convert ${out_folder}/t2s_map_final.nii.gz ${out_folder}/t2s_map_final.mgz --conform_min -nc
	mri_add_xform_to_header -c ${mri_folder}/transforms/talairach.xfm ${out_folder}/GRE_TE_mag_0000_final.mgz ${out_folder}/GRE_TE_mag_0000_final.mgz
	mri_add_xform_to_header -c ${mri_folder}/transforms/talairach.xfm ${out_folder}/t2s_map_final.mgz ${out_folder}/t2s_map_final.mgz

	echo "Fine (bbregister) coregistration T2* to MP2RAGE data..." 	
	# Boundary-based ('fine') registration
	echo "$subject" > "$mri_folder"/transforms/eye.dat
	echo "1" >> "$mri_folder"/transforms/eye.dat
	echo "1" >> "$mri_folder"/transforms/eye.dat
	echo "1" >> "$mri_folder"/transforms/eye.dat
	echo "1 0 0 0" >> "$mri_folder"/transforms/eye.dat
	echo "0 1 0 0" >> "$mri_folder"/transforms/eye.dat
	echo "0 0 1 0" >> "$mri_folder"/transforms/eye.dat
	echo "0 0 0 1" >> "$mri_folder"/transforms/eye.dat
	echo "round" >> "$mri_folder"/transforms/eye.dat

	bbregister --s ${subject} --mov ${out_folder}/GRE_TE_mag_0000_final.mgz --surf white --init-reg ${mri_folder}/transforms/eye.dat --t2 \
		--reg ${out_folder}/transforms/bbregister_to_surface.dat --fslmat ${out_folder}/transforms/bbregister_to_surface.mtx
	mri_convert ${out_folder}/t2s_map_final.mgz ${out_folder}/t2s_map_final.nii.gz
	fsl5.0-flirt -interp spline -in ${out_folder}/t2s_map_final.nii.gz -ref ${out_folder}/t2s_map_final.nii.gz -applyxfm \
		-init ${out_folder}/transforms/bbregister_to_surface.mtx -out ${out_folder}/t2s_map_final.nii.gz
	mri_convert ${out_folder}/t2s_map_final.nii.gz ${out_folder}/t2s_map_final.mgz

	if [ ! -d "${out_folder}/finals/" ] ; then
		mkdir -p ${out_folder}/finals/
	fi	
	if [ ! -d "${out_folder}/intermediates/" ] ; then
		mkdir -p ${out_folder}/intermediates/
	fi

	mv ${out_folder}/t2s_map_final* ${out_folder}/finals/
	mv ${out_folder}/*.nii.gz ${out_folder}/intermediates/
fi

# CBF computation
if [ ${cbf_analysis} == "1" ] ; then
	echo "--------------------------------------------------------------------------------------------------------"
	echo "Processing ASL data for CBF computation" 
	echo "--------------------------------------------------------------------------------------------------------"
	in_folder=${input}/niftis/asl
	out_folder=${input}/processed/asl
	out_folder_t2s=${input}/processed/t2s

	if [ ! -d "${out_folder}/transforms" ] ; then
		mkdir -p ${out_folder}/transforms
	fi

	cd ${in_folder}
	touch tmp.txt
	ls *.nii.gz > tmp.txt

	cp `sed -n '1p' tmp.txt` ${out_folder}/ASL_all_volumes.nii.gz
	cp `sed -n '2p' tmp.txt` ${out_folder}/ASL_M0_volume.nii.gz
	#rm tmp.txt
	
	echo "Motion correcting ASL volumes..."
	fsl5.0-mcflirt -in ${out_folder}/ASL_all_volumes.nii.gz -refvol 0 -spline_final -plots -out ${out_folder}/ASL_all_volumes_mc
	fsl5.0-fslmaths ${out_folder}/ASL_all_volumes_mc.nii.gz -Tmean ${out_folder}/ASL_all_volumes_mc_mean.nii.gz

	echo "Compute mean tag-ctrl image..."
	fsl5.0-asl_file --data=${out_folder}/ASL_all_volumes_mc.nii.gz --ntis=1 --iaf=tc --diff --mean=${out_folder}/ASL_tag-ctrl_mean.nii.gz
	fsl5.0-fslcpgeom ${out_folder}/ASL_all_volumes.nii.gz ${out_folder}/ASL_tag-ctrl_mean.nii.gz
	fsl5.0-fslswapdim ${out_folder}/ASL_tag-ctrl_mean.nii.gz -x y z ${out_folder}/ASL_tag-ctrl_mean.nii.gz
	fsl5.0-fslroi ${out_folder}/ASL_tag-ctrl_mean.nii.gz ${out_folder}/ASL_tag-ctrl_mean.nii.gz 0 1

	echo "Calculating CBF..."
	fsl5.0-flirt -dof 6 -interp spline -in ${out_folder}/ASL_M0_volume.nii.gz -ref ${out_folder}/ASL_all_volumes_mc_mean.nii.gz \
		-omat ${out_folder}/transforms/M0_to_ASL.mat -out ${out_folder}/ASL_M0_volume_coreg.nii.gz
	fsl5.0-fslmaths ${out_folder}/ASL_tag-ctrl_mean.nii.gz -div ${out_folder}/ASL_M0_volume_coreg.nii.gz ${out_folder}/ASL_tag-ctrl_mean_div_by_M0.nii.gz
	fsl5.0-fslmaths ${out_folder}/ASL_tag-ctrl_mean_div_by_M0.nii.gz -mul ${scripts_folder}/2x2_mask_for_CBF_scaling.nii.gz ${out_folder}/ASL_CBF.nii.gz

	fsl5.0-bet ${out_folder}/ASL_M0_volume_coreg.nii.gz ${out_folder}/brain -m -n -R -f 0.2
	fsl5.0-fslmaths ${out_folder}/ASL_CBF.nii.gz -mul ${out_folder}/brain_mask.nii.gz -thr 0 -uthr 200 ${out_folder}/ASL_CBF_brain.nii.gz
	rm ${out_folder}/brain.nii.gz

	echo "Gradient distortion correcting CBF map..."
	fsl5.0-applywarp --rel --interp=spline -i ${out_folder}/ASL_CBF_brain.nii.gz -r ${out_folder}/ASL_CBF_brain.nii.gz \
		-w ${out_folder}/transforms/gdc_warp.nii.gz -o ${out_folder}/ASL_CBF_brain_gdc.nii.gz
	fsl5.0-applywarp --rel --interp=spline -i ${out_folder}/ASL_M0_volume_coreg.nii.gz -r ${out_folder}/ASL_M0_volume_coreg.nii.gz \
		-w ${out_folder}/transforms/gdc_warp.nii.gz -o ${out_folder}/ASL_M0_volume_coreg_gdc.nii.gz

	# Fieldmap correction
	if [ ${cbf_fieldmap_correction} == "1" ] ; then
		echo "Fieldmap correction and fine (bbregister) coregistration CBF map to MP2RAGE data..." 
		in_folder_fieldmap=${input}/niftis/fieldmap
		out_folder_fieldmap=${input}/processed/fieldmap
		fsl5.0-applywarp --rel --interp=spline -i ${out_folder_fieldmap}/intermediates/brain.nii.gz -r ${out_folder_fieldmap}/intermediates/brain.nii.gz \
			-w ${out_folder_fieldmap}/transforms/gdc_warp.nii.gz -o ${out_folder_fieldmap}/intermediates/brain_gdc.nii.gz
		fsl5.0-applywarp --rel --interp=spline -i ${out_folder_fieldmap}/finals/fieldmap_rads.nii.gz -r ${out_folder_fieldmap}/finals/fieldmap_rads.nii.gz \
			-w ${out_folder_fieldmap}/transforms/gdc_warp.nii.gz -o ${out_folder_fieldmap}/finals/fieldmap_rads_gdc.nii.gz
	
		fsl5.0-flirt -dof 6 -in ${out_folder_fieldmap}/intermediates/brain_gdc.nii.gz -ref ${out_folder}/ASL_M0_volume_coreg_gdc.nii.gz -omat ${out_folder_fieldmap}/transforms/fieldmap_to_asl.mat
		fsl5.0-flirt -interp spline -in ${out_folder_fieldmap}/finals/fieldmap_rads_gdc.nii.gz -ref ${out_folder}/ASL_M0_volume_coreg_gdc.nii.gz -applyxfm \
			-init ${out_folder_fieldmap}/transforms/fieldmap_to_asl.mat -out ${out_folder_fieldmap}/finals/fieldmap_rads_gdc_coreg.nii.gz
	
		fsl5.0-fugue --loadfmap=${out_folder_fieldmap}/finals/fieldmap_rads_gdc_coreg.nii.gz --dwell=${ASLdwell} --saveshift=${out_folder_fieldmap}/finals/shiftmap_rads_gdc_coreg.nii.gz
		fsl5.0-convertwarp --relout --rel --ref=${out_folder_fieldmap}/finals/shiftmap_rads_gdc_coreg.nii.gz \
			--shiftmap=${out_folder_fieldmap}/finals/shiftmap_rads_gdc_coreg.nii.gz --shiftdir=y- --out=${out_folder_fieldmap}/finals/shiftmap_rads_final.nii.gz
	
		fsl5.0-applywarp --rel --interp=spline -i ${out_folder}/ASL_M0_volume_coreg_gdc.nii.gz -r ${out_folder}/ASL_M0_volume_coreg_gdc.nii.gz \
			-w ${out_folder_fieldmap}/finals/shiftmap_rads_final.nii.gz -o ${out_folder}/ASL_M0_volume_coreg_gdc_fieldmap.nii.gz
		fsl5.0-applywarp --rel --interp=spline -i ${out_folder}/ASL_CBF_brain_gdc.nii.gz -r ${out_folder}/ASL_CBF_brain_gdc.nii.gz \
			-w ${out_folder_fieldmap}/finals/shiftmap_rads_final.nii.gz -o ${out_folder}/ASL_CBF_brain_gdc_fieldmap.nii.gz
	
		fsl5.0-fslreorient2std ${out_folder}/ASL_CBF_brain_gdc_fieldmap.nii.gz ${out_folder}/ASL_CBF_brain_gdc_fieldmap_std.nii.gz
		fsl5.0-fslreorient2std ${out_folder}/ASL_M0_volume_coreg_gdc_fieldmap.nii.gz ${out_folder}/ASL_M0_volume_coreg_gdc_fieldmap_std.nii.gz
	
		bbregister --s ${subject} --mov ${out_folder}/ASL_M0_volume_coreg_gdc_fieldmap_std.nii.gz --t2 --reg ${out_folder}/transforms/bbregister_to_surface.dat --init-fsl
		mri_vol2vol --mov ${out_folder}/ASL_CBF_brain_gdc_fieldmap_std.nii.gz --targ ${mri_folder}/orig.mgz --o ${out_folder}/ASL_CBF_brain_final.nii.gz \
			--reg ${out_folder}/transforms/bbregister_to_surface.dat
	else

		echo "Fine (bbregister) coregistration CBF map to MP2RAGE data..." 	
		fsl5.0-fslreorient2std ${out_folder}/ASL_CBF_brain_gdc.nii.gz ${out_folder}/ASL_CBF_brain_gdc_std.nii.gz
		fsl5.0-fslreorient2std ${out_folder}/ASL_M0_volume_coreg_gdc.nii.gz ${out_folder}/ASL_M0_volume_coreg_gdc_std.nii.gz
	
		bbregister --s ${subject} --mov ${out_folder}/ASL_M0_volume_coreg_gdc_std.nii.gz --t2 --reg ${out_folder}/transforms/bbregister_to_surface.dat \
			--init-fsl
		mri_vol2vol --mov ${out_folder}/ASL_CBF_brain_gdc_std.nii.gz --targ ${mri_folder}/orig.mgz --o ${out_folder}/ASL_CBF_brain_final.nii.gz \
			--reg ${out_folder}/transforms/bbregister_to_surface.dat
	fi

	if [ ! -d "${out_folder}/finals/" ] ; then
		mkdir -p ${out_folder}/finals/
	fi	
	if [ ! -d "${out_folder}/intermediates/" ] ; then
		mkdir -p ${out_folder}/intermediates/
	fi

	mv ${out_folder}/*.par ${out_folder}/transforms/
	mv ${out_folder}/*final.nii.gz ${out_folder}/finals/
	mv ${out_folder}/*.nii.gz ${out_folder}/intermediates/	
fi



