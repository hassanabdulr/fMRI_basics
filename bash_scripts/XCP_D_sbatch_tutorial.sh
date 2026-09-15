#!/bin/bash -l

##################### XCP-D tutorial: continuation of the fMRIPrep tutorial
#
# This is the next step after fMRIPrep. Before using this script, go back to
# the fMRIPrep tutorial and make sure you understand its project layout,
# subject-list setup, Slurm arrays, logs, and resource requests.
#
# XCP-D does not start from raw BIDS data here. It reads the fMRIPrep
# derivatives in BIDS_DIR, so fMRIPrep must have completed successfully for
# the subjects you want to process. Confirm that the fMRIPrep version,
# derivatives, and participant labels match this XCP-D workflow.
#
# IMPORTANT: do not denoise data "willy nilly" or change these settings just
# because they seem reasonable. Read the XCP-D documentation, discuss the
# analysis with your supervisor and other researchers working with the dataset,
# and read papers using similar datasets and participant populations. Agree on
# the confounds, motion threshold, censoring, filtering, smoothing, and other
# choices before running the full study. These decisions affect the scientific
# results and must be reported in your methods.


# XCP documentation : https://xcp-d.readthedocs.io/en/latest/index.html

##################### Slurm 

# I went into detail in the fMRIPrep tutorial, so here just make sure you 
# understand the derectives of the slurm and adjust things to make your jobs more efficient.
# So start with one subject, then use `seff JOB_ID` to inspect
# resource usage before submitting the whole array.
#SBATCH --partition=high-moby
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=20G
#SBATCH --time=12:00:00
#SBATCH --array=1-XXXX
#SBATCH --job-name=TAY_XCP
#SBATCH --output=/projects/aabdulrasul/TAY/XCP/logs/%x_%A_%a.out
#SBATCH --error=/projects/aabdulrasul/TAY/XCP/logs/%x_%A_%a.err

set -euo pipefail

##################### Paths

# OUTPUT_DIR receives XCP-D derivatives. WORK_DIR contains temporary files
# and can become large. Keep it until you have confirmed that the run finished
# and the outputs are usable. Then delete that ish

OUTPUT_DIR="/projects/aabdulrasul/TAY/XCP/output"
SINGULARITY_IMG="/projects/aabdulrasul/TAY/XCP/code/xcp_d-0.14.1.simg" # note the version, discuss with your supervisor!!
WORK_DIR="/projects/aabdulrasul/TAY/XCP/work"

# This is fMRIPrep output, not the original raw BIDS directory. Check that it
# contains the expected fMRIPrep derivatives and that the XCP-D version is
# compatible with them. Do not run XCP-D on raw BIDS data with this setup!!
BIDS_DIR="/path/to/fmriprep/output" 

# One subject label per line. This tutorial expects labels such as sub-001.
# The array task number selects the corresponding line in this file.
SUBJECT_LIST="/projects/aabdulrasul/TAY/XCP/code/subject_list.txt"
FS_LICENSE="/scratch/smansour/freesurfer/6.0.1/build/license.txt"

# Just like the fMRIPrep tutorial, the array task number selects the corresponding participant label

index() {
   head -n $SLURM_ARRAY_TASK_ID $SUBJECT_LIST \
   | tail -n 1
}

# Get the current participant label
FULL_LABEL=$(index)

# Extract the part after 'sub-'
PARTICIPANT_LABEL=$(echo $FULL_LABEL | cut -d'-' -f2)

##################### Run XCP-D

# bind the paths to the container and run XCP-D. The options below are explained in the comments.
singularity run --cleanenv \
    -B "${BIDS_DIR}:/bids_dir" \
    -B "${OUTPUT_DIR}:/output_dir" \
    -B "${WORK_DIR}:/work_dir" \
    -B "${FS_LICENSE}:/li" \
    "${SINGULARITY_IMG}" \
    /bids_dir /output_dir participant \
    --participant-label "${PARTICIPANT_LABEL}" \
    --fs-license-file /li \
    --mode none \
    --despike y \
    --fd-thresh 0.3 \
    -p 36P \
    --motion-filter-type notch \
    --band-stop-min 12 \
    --band-stop-max 20 \
    --warp-surfaces-native2std y \
    --input-type fmriprep \
    --file-format cifti \
    --combine-runs n \
    --dummy-scans 4 \
    --abcc-qc y \
    --linc-qc y \
    --output-run-wise-correlations n \
    --min-coverage 0.5 \
    --output-type censored \
    --smoothing 6 \
    --verbose \
    -w /work_dir

##################### What the command options mean

# The following settings are documented here so you know what
# to investigate. PLEASE note that these are not universal defaults:
#
# --mode none                 Selects the XCP-D processing mode. In the latest version of XCP, you can essentially replicate a few studies denoising pipelines, by selecting the mode
#                             Here we set it as none, because we want to customize a few things. If you want to use a prebuilt mode, check the XCP-D documentation for the available modes and their settings.
# --despike y                 Applies despiking; removing the large spikes in the time series. very common, but again confirm with the literature and your supervisor that this is appropriate for your data.
#
# --fd-thresh 0.3            Sets the framewise-displacement threshold used, anything above this threshold will be marked.
#                             for motion handling/censoring.
# -p 36P                     Requests the 36-parameter confound strategy. these are all motion parameters, their derivatives, squares of the derivatives, along with global signal, white matter signal, and CSF signal. This is very common, but again confirm with the literature and your supervisor.
#                            Refer to the documentation to see how to include what regressors you want to denoise with
#
# --motion-filter-type notch  this removes the respiratory and motion from the head. if you include this, you need to also include the min and max band stop frequencies. this is respiratory driven (breaths per minute)
#
# --band-stop-min/max 12/20  minimum breaths and maximum breaths per minute. XCP documentation has a nice table of the common ranges. refer to that!
#
# --warp-surfaces-native2std  Warps native surfaces to standard space.
#
# --input-type fmriprep      Tells XCP-D the input is fMRIPrep output. note that xcp can take tonnes of other inputs, check the documentation for other input types.
# --file-format cifti        Requests CIFTI input/output handling. for high resolution surface data, this is the preferred format, as we can get high parcellations.
# --combine-runs n            Keeps runs separate rather than combining them. I personally prefer to do this separately, as I don't want the motion from run 2 to affect run 1, but this is a choice you can make. 
# --dummy-scans 4             drops the first 4 TRs (recall why this is necessary)

# --abcc-qc / --linc-qc       Enables these quality-control HTML outputs.

# --output-run-wise-correlations n   XCP actually can make you the correlation matrices for each run. I think this is best for you to do after the fact, as you can then combine runs if you want, and also do it for each run separately. Also lowkey, I want to do it to make sure I did it correctly, I don't want to hand over a part of my analysis that i can easily do.

# --min-coverage 0.5          per parcel coverage threshold. if a parcel has less than 50% coverage, it will be marked. Note that this is a common threshold, but again, check the literature and your supervisor to see if this is appropriate.
# --output-type censored      This is arguable the most important feature, for each "marked" part of the timeseries, how would you like to handle it? 
#                             Censoring means, that datapoint or TR is dropped from the final denoised timeseries. Note this effectively shortens your timeseries duration.
#                             The longer your scan, the more you can afford to censor, but also the longer a cleaned timeseries the more reliable the BOLD signal is actually coming from brain.
#                             This is a choice you need to make with your supervisor. I personally always censor, because I will likely have a second run I can concatenate with to increase the timeseries length
#                             The other option is to interpolate, which means that the marked TRs are replaced with an interpolated value based on the surrounding TRs. This is a choice you need to make with your supervisor. I personally don't like this, because it can introduce artificial signal into the timeseries, and I really don't think you can "average out" brain activation, especially for a task signal or a lot of TRs being dropped.
# --smoothing 6               Applies a smoothing of the boundaries of the parcels, such that the BOLD signal is more representative of the parcel. the larger the smoothing, the more the signal is "averaged" across the parcel. this is a choice you need to make with your supervisor.
# --verbose                   Prints more detail to the Slurm output log.
# -w /work_dir                Places temporary work in the bound work folder.
#
# Before changing any of these options, consult XCP-D documentation and
# discuss the complete denoising plan with your supervisor. In particular,
# agree on nuisance/confound regression, motion thresholding and censoring or interpolating marked TRs,
# temporal filtering, smoothing, dummy-scan handling, and QC criteria. Review
# methods from studies with comparable scanners, tasks, and demographics; do
# not assume that a strategy suitable for another population is automatically
# suitable for yours. For example, if a study was studying older adults, and you are studying youth, the motion and denoising strategy would be wildly different.

##################### Submission checklist
#
# 1. Complete the fMRIPrep tutorial first and verify the fMRIPrep derivatives.
# 2. Create the XCP-D directories and the Slurm log directory:
#      mkdir -p /projects/aabdulrasul/TAY/XCP/{code,logs,test,work}
# 3. Confirm the container, FreeSurfer license, and fMRIPrep input directory:
#      ls -lh "$SINGULARITY_IMG" "$FS_LICENSE" "$BIDS_DIR"
# 4. Create SUBJECT_LIST with one full label per line, for example:
#      sub-001
#      sub-002
# 5. Replace --array=1-XXXX with the number of subjects, or start with
#    --array=1 for a test run.
# 6. Submit the job:
#      sbatch /projects/aabdulrasul/Tutorials/fMRI_basics/bash_scripts/run_xcp_TAY_ABCD.sh
# 7. Monitor the job and inspect the subject-specific .out and .err logs:
#      squeue -u "<your_username>"
#      seff JOB_ID
# 8. Check XCP-D QC reports and outputs before proceeding with analysis.

