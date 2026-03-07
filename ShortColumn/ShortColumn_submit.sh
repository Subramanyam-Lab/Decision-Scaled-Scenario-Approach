#!/bin/bash

# Create directories for logs and results
mkdir -p logfiles
mkdir -p results

# Parameters for Short Column
epsilon_levels=(0.00001)
s_values=(1.0 1.1 1.2)

# Submit array jobs for each combination
for epsilon in "${epsilon_levels[@]}"; do
    for s in "${s_values[@]}"; do
        job_name="SC_e${epsilon}_s${s}"
        
        # Submit to sla-prio partition
        sbatch --partition=sla-prio \
               --account=azs7266_sc \
               --nodes=1 \
               --ntasks-per-node=1 \
               --cpus-per-task=3 \
               --mem=32GB \
               --time=01:30:00 \
               --job-name=${job_name} \
               --array=1-100%14 \
               --output=logfiles/${job_name}_%a.out \
               --error=logfiles/${job_name}_%a.err \
               --wrap="module load julia/1.11.2 gurobi && \
                       export JULIA_DEPOT_PATH=/storage/home/jxc6747/.julia/depot && \
                       export MOSEK_HOME=\$HOME/mosek/11.0 && \
                       export MOSEKLM_LICENSE_FILE=\$HOME/mosek.lic && \
                       julia --project=. --threads=\$SLURM_CPUS_PER_TASK ShortColumn_run.jl --epsilon=${epsilon} --s=${s} --trial=\$SLURM_ARRAY_TASK_ID"
        
        echo "Submitted sla-prio array job: ${job_name}"
        sleep 2
    done
done