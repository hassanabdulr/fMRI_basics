#!/bin/bash -l

##################### fMRIPrep tutorial

# This file is a Slurm *batch script*. It is submitted with the command `sbatch`
# what makes it a sbatch script is the #sbatch directives below. This tells the cluster what we want
# to do and how we want to do it. the rest of the script is a bash script. Note you can make a sbatch
# script that isn't a bash script, for example, python or r scripts. but thats for another time.

# Before submitting this file, complete the setup checklist at the bottom.
# The example below uses the TAY study and the my project folder.
# Replace these example values with your respective data and project path


# fMRIPrep documentation: https://fmriprep.org/en/stable/


##################### Slurm resource requests

# These lines are read by Slurm when the job is submitted. They must be placed
# near the top of the file and with complete lines and values.

#### IMPORTANT ####: create the LOG_DIR before submitting, because Slurm opens the log
# files before the script itself starts running. and you can open the log yourself to see how things are running or if there are any errors

#### IMPORTANT #### : array refers to the subject list, or in other words, how many jobs you want to run.
                  # so if you have 20 subjects, you would set --array=1-20. threby 20 jobs of fmriprep will be run, one for each subject.
                  # the array is 1-indexed, meaning the first job is 1, not 0. so if you have 20 subjects, the last job will be 20, not 19.
                  # we pass the subject list as the array, therefore subject 1 will be the first line of the subject list, subject 2 will be the second line
                  # and so on.

#### IMPORTANT ####: partition, time, memory, and CPU limits are all job specific. really its trial and error to find the right values
                   # my advice is start with array=1, then run the job and see how long it takes, how much memory it uses, and how many CPUs it uses. then adjust the values accordingly.

# as always if you're confused reach out to staff, other students, don't hesitate to ask questions. we are all here to help!!!!!!!!!

#SBATCH --partition=high-moby #### this partition is the one used for priority tasks. to check available partitions, run `sinfo` on the command line. if you are unsure which partition to use, ask staff or other students.
#SBATCH --array=1-29 
#SBATCH --nodes=1 #### this refers to how many nodes you want to use. a node is a single computer in the cluster. for fmriprep, we only need one node. you'd only adjust this if you were running a job that required multiple nodes, like a large simulation or a big data analysis.
#SBATCH --mem-per-cpu=4000 ##### this is memory in mb, so 4000 mb = 4 gb. this is the amount of memory per cpu core. a reasonable starting point for fmriprep is 4 gb per cpu core. if you run out of memory, increase this value. if you have a lot of memory left over, decrease this value to free up resources for other jobs.
#SBATCH --cpus-per-task=6 #### this is number of cores to use for the job. fmriprep can use multiple cores, check the documentation for more information. a reasonable starting point is 4 or 6 cores. if you run out of memory, decrease this value or increase memory. if you have a lot of memory left over, increase this value
#SBATCH --time=20:00:00 ##### this is the maximum time the job will run. if the job takes longer than this, it will be killed. for your first run, do 20 hours. if it finishes in less time you can adjust this.
#SBATCH --export=ALL #### this is to export all environment variables to the job. this is usually what you want, leave this as is.
#SBATCH --job-name=TAY_fmriprep #### this is the job name per the cluster. you can change this to whatever you want, so when you look into the queue, you can see your job.
#SBATCH --output=/projects/aabdulrasul/TAY/fmriprep/log/%x_%A_%a.out #### output log that contains all the print statements from the job. %x is the job name, %A is the job id, and %a is the array index. this is useful for debugging and checking the progress of the job
#SBATCH --error=/projects/aabdulrasul/TAY/fmriprep/log/%x_%A_%a.err #### error log that contains all the error messages from the job. %x is the job name, %A is the job id, and %a is the array index. this is useful for debugging and checking the progress of the job


### to check the resource usage of the job you can use the command seff job_id, where job_id is the job id of the job you want to check. this will give you a summary of the job's resource usage, including memory, time, and cpu usage
  # if you're unsure of the job id, go to your log directory and look for the job name and array index. the job id is the number after the job name and before the array index. for example, if your job name is TAY_fmriprep_12345_1, then the job id is 12345.
  # so you can type seff 12345 to see the resource usage of that job. 
  # important to note, while yes one jobs usage will give you a good idea of the resources needed, it might not be accurate all the time. Compute requirements can increase based on many factors
  # example, if they completed more than 2 runs of rest and task, or if they have very messy data, the cleaning and aligning that fmriprep does will require more compute. 
  # so just be aware that things could fail or run out of memory, as always READ the logs and check the output of the job to see if it completed successfully


# Stop immediately if a command fails, a variable is missing, or a pipeline
# fails. These options make setup mistakes easier to diagnose.
set -euo pipefail

############## Step 0: make your project folder for the study and copy the raw BIDS data

# Recommended project layout: this is what most staff do

# /projects/YOUR_USERNAME/YOUR_STUDY/fMRIprep/
# |-- bids/             raw BIDS input copied from the archive
# |-- code/             scripts and subject lists
# |-- log/              Slurm output and error logs
# |-- output/           fMRIPrep derivatives (the results to keep)
# |-- work/             temporary working files (can become very large)
# |-- templates/        *optional* local TemplateFlow cache
#
# you can of course add more folders, or anything, just make sure the subdirs you need for fmriprep to run are consistent with the paths you set below.
# you can also include a README file in the project folder to document the project and the analysis. this is good practice because we will forget!

touch /projects/aabdulrasul/TAY/fmriprep/README.md

# Create this layout before submitting, for example:
#
#   mkdir -p /projects/aabdulrasul/TAY/fmriprep/{code,bids,log,output,work,templates}
#        -p here creates the parent directories if they don't exist, and does not give an error if they already exist.
#
# For a different study, change STUDY and PROJECT_DIR, and also update the
# two --output/--error lines above!!!!!!

STUDY="TAY"
PROJECT_DIR="/projects/aabdulrasul/${STUDY}"

mkdir -p /projects/aabdulrasul/TAY/fmriprep/{code,bids,log,output,work,templates}

############## Step 1: make a subject list


# Put one participant label on each line. Do not include spaces, comments, or
# extra columns. The labels must match the directory names in bids/.
#
# For a BIDS directory named `sub-001`, fMRIPrep will accept the numerical label so it will accept `001` as
# --participant-label. So you can either make the subject list with the `sub-` prefix or without it. then in the call to fmriprep you can remove the sub- prefix
#
#   sub-001
#   sub-002
#   sub-017
#
# Make the array range above match the number of non-empty lines in this file.
SUBJECT_LIST="${PROJECT_DIR}/fmriprep/code/subject_list.txt" # or whatever you want to call it, just make sure to update the path in the sbatch directives above and in the code below

### if you want to include the sub- prefix for simplicity, you can use this function below to remove the sub and pass the variable that contains the non sub- label

index() {
   head -n $SLURM_ARRAY_TASK_ID $SUBJECT_LIST \
   | tail -n 1
}

# this function above matches the array index to the line in the subject list. so if you have 29 subjects, and you set --array=1-29, then the first job will run on the first line of the subject list, the second job will run on the second line of the subject list, and so on.
# it returns the subject line it is currently working on, and then we can use that to set the PARTICIPANT_LABEL variable below.

sub=`index` # index returns the subject line it is working on (as described above)
sub=$(echo "$sub" | tr -d '\r')   # this returns the numerical label of the subject.
PARTICIPANT_LABEL="$sub"  # we now assign the PARTICIPANT_LABEL variable to the subject label that we just got from the subject list. this is what we will pass to fmriprep below. note it is now cleaned, so it doesn't have the sub- prefix.



############## Step 2: define the input, output, and software paths




BIDS_DIR="${PROJECT_DIR}/fmriprep/bids" 
OUT_DIR="${PROJECT_DIR}/fmriprep/output"
WORK_DIR="${PROJECT_DIR}/fmriprep/work"
LOG_DIR="${PROJECT_DIR}/fmriprep/log"

# Copy raw BIDS data from the archive before submitting this script. This is
# deliberately not done inside every array task, because 29 tasks copying the
# same data at once would waste storage and slow things down. So copy the data once, then run the job.
#
#   cp -r /archive/data/TAY/data/bids/ /path/to/your/project/bids/
#
# Confirm that the copied directory contains subject folders 
# you should also copy the dataset_description.json. to the bids directory. this is important for fmriprep to run correctly. 

# These two paths are site-specific
# administrator where the shared FreeSurfer license and fMRIPrep container are.

FS_LICENSE="/scratch/smansour/freesurfer/6.0.1/build/license.txt" # there is a license somehwere that isn't in someones folder, but i forgot where so i just use Salims 
SING_CONTAINER="/scratch/galinejad/ScanD/containers/fmriprep-23.2.3.simg" # this is the path to the container that we will use to run fmriprep. Note the version! for people rerunning the failed QC, ensure you have the right version (i think 23.2.3 is the one we used for the TAY study, but check with staff if you are unsure).

# TemplateFlow downloads templates the first time they are needed. Keeping a
# reusable cache in the project avoids downloading them separately for every
# subject. It is okay to start with an empty directory.
TF_DIR="${PROJECT_DIR}/templates"
export APPTAINERENV_TEMPLATEFLOW_HOME="/home/fmriprep/.cache/templateflow"



##### Step 3: run fMRIPrep in the  Singularity container



# The container provides the fMRIPrep software and its dependencies. Each -B
# option binds a directory on the cluster (left side) to a path inside the
# container (right side), so the container can read inputs and write outputs.
# remember, the cointainer is a silo'd environment, so it doesn't have access to the cluster's file system unless you bind it!
# The settings in this block are dataset- and analysis-specific. Do not copy
# them blindly to another study: read the fMRIPrep documentation and confirm
# why each option is appropriate for your data and research question. Again, if you're confused ask Staff, students, PIs who are working with the same data.
#
# In particular, review --ignore fieldmaps, --force-syn/--use-syn-sdc,
# --ignore slicetiming, --cifti-output, --level, and --skull-strip-t1w.
# `--skip-bids-validation` is convenient only when you have already validated
# the BIDS dataset; omitting validation can hide input-data problems.
singularity run --cleanenv \
   -H /home/fmriprep \
   -B "${TF_DIR}:/home/fmriprep/.cache/templateflow" \
   -B "${BIDS_DIR}:/bids" \
   -B "${OUT_DIR}:/out" \
   -B "${WORK_DIR}:/work" \
   -B "${FS_LICENSE}:/license.txt" \
   "${SING_CONTAINER}" \
   /bids /out participant \
   --participant-label "${PARTICIPANT_LABEL}" \
   -w /work \
   --skip-bids-validation \
   --cifti-output 91k \
   --omp-nthreads 6 \
   --nthreads 6 \
   --mem-mb 40000 \
   --ignore fieldmaps \
   --force-syn \
   --use-syn-sdc \
   --ignore slicetiming \
   --level full \
   --skull-strip-t1w force \
   --fs-license-file /license.txt

########### Submission checklist


# 1. Create the project layout, including LOG_DIR:
#      mkdir -p /projects/aabdulrasul/TAY/fmriprep/{code,bids,log,output,work,templates}
# 2. Copy the raw BIDS data once:
#      cp -r /archive/data/TAY/data/bids/. /projects/aabdulrasul/TAY/fmriprep/bids/
# 3. Create and inspect the subject list:
#       /projects/aabdulrasul/TAY/fmriprep/code/subject_list.txt
#      cat /projects/aabdulrasul/TAY/fmriprep/code/subject_list.txt # to print it
# 4. Check that --array=1-N equals the number of subjects in the list.
# 5. Check the partition, license, container, and paths for your cluster.
# 6. submit the job: note your first job should just be 1 array to test that everything is working. and also learn the resource usage of the job. 
#      sbatch /projects/aabdulrasul/Tutorials/fMRI_basics/bash_scripts/run_fMRIprep.sh
# 7. Monitor it:
#      squeue 
#    If there are loads of jobs and you're overwhelmed reading you can use this command
#      squeue -u <your_username>

# 8. Read the files in log/ before trusting the outputs. Check one subject in
#    output/ and inspect fMRIPrep's HTML report for warnings or errors.
#
# Tips and things to know:

# - Only staff have write privleges on the archive, so you can copy but not save to archive (or delete) so you're good!
# - You have full control of your projects folder, you can write, delete, and modify files there. so as always, be careful and don't delete anything you don't want to delete.
# - A FreeSurfer license and the exact container must be actually there before you run things, use ls -lh /path/to/license.txt and ls -lh /path/to/container.simg to check that they are there 
# - Working directory should be deleted once a job is done! if you have any doubts about the status of a job, check the log files.
# - if a job fails, its always good practice to delete the working directory, and also the output directory for that subject, and then rerun the job
# - Always read the logs if you notice an error, search it up and troubleshoot it. if you can't figure it out, ask staff or other students for help!



## if you'd like to see some examples of fmriprep sbatch scripts here are the paths to them below

# /projects/aabdulrasul/Tutorials/fMRI_basics/bash_scripts/run_fMRIprep.sh
# /projects/aabdulrasul/SPINR/FMRIPREP/code/run_fmriprep.sh
# /projects/aabdulrasul/SPASD/FMRIPREP/code/run_fmriprep_w_fs.sh
# /projects/aabdulrasul/SPASD/FMRIPREP/code/run_fmriprep.sh