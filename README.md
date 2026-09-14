# fMRI_basics

This repository contains beginner-friendly notebooks for foundational fMRI analysis workflows.

## Scope

- Work with **parcellated BOLD TSV** timeseries files
- Concatenate runs and compute correlation matrices for downstream analysis
- Inspect and understand derivative outputs from **fMRIPrep**, **FreeSurfer**, and **XCP-D**

## Notebooks

- `notebooks/01_concatenate_and_correlate_parcellated_bold.ipynb`
  - Loads parcellated BOLD TSV files, concatenates runs, computes parcel correlations, and writes outputs
- `notebooks/02_inspect_fmriprep_freesurfer_xcpd_outputs.ipynb`
  - Walks through typical derivative outputs from fMRIPrep/FreeSurfer/XCP-D

These notebooks are intended as practical templates that you can adapt to your dataset structure.
