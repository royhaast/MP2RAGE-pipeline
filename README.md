#MP2RAGE analysis pipeline

High-res analysis pipeline for MP2RAGE data, losely based on HCP's
anatomical pipeline.

###Software requirements:
 	- FSL (5.0)
	http://fsl.fmrib.ox.ac.uk/fsl/fslwiki/
		
	- ANTs (latest release)
	https://github.com/stnava/ANTs

	- CBS tools (including MIPAV and JIST, latest releases)
	https://www.nitrc.org/projects/cbs-tools/
	https://mipav.cit.nih.gov/

	- FreeSurfer v6.0 (stable)
	https://surfer.nmr.mgh.harvard.edu/

	- MATLAB (e.g. R2015b)
	- B1 correction code from J.P. Marques (and MATLAB)

###Tested on Linux system with:
	- 32 gb RAM
	- 16 cores
	- GPU CUDA v5.0 installed
	- Debian Wheezy (necessary for CUDA support)

*Total processing time per subject:...*

