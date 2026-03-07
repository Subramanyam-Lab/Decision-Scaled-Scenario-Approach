#!/bin/bash

# Create directories for logs and results
mkdir -p logfiles
mkdir -p results

# Parameters
epsilon_levels=(0.001 0.0001 0.00001)
s_values=(1.2)

# Submit array jobs for each combination
for epsilon in "${epsilon_levels[@]}"; do
    for s in "${s_values[@]}"; do
        job_name="Portfolio_e${epsilon}_s${s}"
        
        # sla-prio partition
        sbatch --partition=sla-prio \
               --account=azs7266_sc \
               --nodes=1 \
               --ntasks-per-node=1 \
               --cpus-per-task=3 \
               --mem=32GB \
               --time=01:30:00 \
               --job-name=${job_name} \
               --array=1-100%12 \
               --output=logfiles/${job_name}_%a.out \
               --error=logfiles/${job_name}_%a.err \
               --wrap="module load julia gurobi && export JULIA_DEPOT_PATH=/storage/home/jxc6747/.julia/depot && julia --project --threads=\$SLURM_CPUS_PER_TASK Portfolio_run.jl --epsilon=${epsilon} --s=${s} --trial=\$SLURM_ARRAY_TASK_ID"
        
        echo "Submitted sla-prio array job: ${job_name}"
        sleep 2        
    done
done

echo "All jobs submitted!"