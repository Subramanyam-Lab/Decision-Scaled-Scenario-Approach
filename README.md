# Decision-Scaled Scenario Approach for Rare Chance-Constrained Optimization

This repository contains the data, source code, and execution scripts to reproduce the numerical experiments presented in the paper **Decision-Scaled Scenario Approach for Rare Chance-Constrained Optimization**. 

Our proposed decision-scaling method significantly reduces the sample size requirements for the scenario approach in the rare-event regime, while guaranteeing asymptotic feasibility. We provide everything needed to reproduce our results across three benchmark problems: Norm Optimization, Portfolio Optimization, and Short Column Design Problems. 

## Table of Contents
- [Repository Structure](#repository-structure)
- [Installation \& Requirements](#installation--requirements)
- [Reproducing the Results](#reproducing-the-results)
- [Citation](#citation)

## Repository Structure

```text
Decision-Scaled-Scenario-Approach/
├── Project.toml                 # Julia project dependencies
├── Manifest.toml                # Exact versions of all Julia packages for reproducibility
├── precompile.sh                # SLURM script (Not in repo; create this file using the template below)
│
├── NormOpt/                     # Norm Optimization Benchmark
│   ├── Norm_Opt_run.jl          # Main execution script
│   ├── functions.jl             # Helper functions
│   └── submit.sh                # SLURM script (Not in repo; create this file using the template below)
│
├── Portfolio/                   # Portfolio Optimization Benchmark
│   ├── Portfolio_run.jl
│   ├── functions.jl
│   └── submit.sh                # SLURM script (Not in repo; create this file using the template below)
│
└── ShortColumn/                 # Reliability-based Short Column Design Benchmark
    ├── ShortColumn_run.jl
    ├── functions.jl
    └── submit.sh                # SLURM script (Not in repo; create this file using the template below)
```

## Installation & Requirements
The experiments were implemented and tested using **Julia 1.11.2** and **JuMP 1.30.0**

### Solvers & Licenses
To run the full suite of experiments, you will need valid commercial or academic licenses for the following solvers:
* **Gurobi (v13.0.0)**: Used for the Portfolio Optimization problem. ([Link](https://www.gurobi.com))
* **Mosek (v11.0.27)**: Used for the Short Column and Norm Optimization problems. ([Link](https://www.mosek.com/))

### Setting up the Environment
We provide a Julia environment to ensure reproducibility.

1. **Clone the repository:**

   ```bash
   git clone https://github.com/Subramanyam-Lab/Decision-Scaled-Scenario-Approach.git
   cd Decision-Scaled-Scenario-Approach
   ```
2. **Precompile the packages (HPC / SLURM users):**

    Before running the individual experiments, you must instantiate and precompile the environment. You can create a `precompile.sh` script with the following template. **Please ensure you edit the partition, account, and solver paths to match your specific cluster environment.**

   ```bash
   #!/bin/bash
   #SBATCH --partition=YOUR_PARTITION
   #SBATCH --account=YOUR_ACCOUNT
   #SBATCH --nodes=1
   #SBATCH --ntasks-per-node=1
   #SBATCH --mem=32GB
   #SBATCH --time=00:30:00
   #SBATCH --job-name=precompile_all
   #SBATCH --output=precompile_%j.out

   # 1. Load modules (Update based on your HPC environment)
   module purge
   module load julia/1.11.2 gurobi

   # 2. Set directory for packages (Optional: set your own Julia depot path)
   export JULIA_DEPOT_PATH=/path/to/your/.julia/depot

   # 3. Set Mosek environment variables (Update with your paths)
   export MOSEK_HOME=/path/to/your/mosek/11.0
   export MOSEKLM_LICENSE_FILE=/path/to/your/mosek.lic

   # 4. Instantiate and Precompile
   julia --project=. -e 'import Pkg; Pkg.instantiate(); Pkg.precompile()'

   echo "Precompilation complete!"
   ```
   
   Once created and modified, submit the job:
   ```bash
   sbatch precompile.sh
   ```
   *Note: If you are running locally, you can simply run `julia --project=. -e 'import Pkg; Pkg.instantiate(); Pkg.precompile()'` in your terminal.*

## Reproducing the Results

Each benchmark folder should contain a `submit.sh` script designed to run the experiments across different risk tolerance levels ($\varepsilon$) and scaling parameters ($s$) using SLURM array jobs.

### Running via SLURM

1. Navigate to the desired experiment folder (e.g., `NormOpt`):
   ```bash
   cd NormOpt
   ```

2. **Important:** First, you should create a `precompile.sh` script with the template below. Before running, you must edit the `#SBATCH` directives (`partition`, `account`) and the `export` paths for your local Julia and solver installations. 

   ```bash
   #!/bin/bash

   # Create directories for logs and results
   mkdir -p logfiles
   mkdir -p results

   # Parameters
   epsilon_levels=(0.001 0.0001 0.00001)
   s_values=(1.0 1.1 1.2)

   # Submit array jobs for each combination
   for epsilon in "${epsilon_levels[@]}"; do
       for s in "${s_values[@]}"; do
           job_name="NormOpt_e${epsilon}_s${s}"
           
           sbatch --partition=YOUR_PARTITION \
                  --account=YOUR_ACCOUNT \
                  --nodes=1 \
                  --ntasks-per-node=1 \
                  --cpus-per-task=3 \
                  --mem=32GB \
                  --time=01:30:00 \
                  --job-name=${job_name} \
                  --array=1-100%10 \
                  --output=logfiles/${job_name}_%a.out \
                  --error=logfiles/${job_name}_%a.err \
                  --wrap="module purge && module load julia/1.11.2 && export JULIA_DEPOT_PATH=/path/to/your/.julia/depot && export MOSEK_HOME=/path/to/your/mosek/11.0 && export MOSEKLM_LICENSE_FILE=/path/to/your/mosek.lic && julia --project=.. --threads=\$SLURM_CPUS_PER_TASK Norm_Opt_run.jl --epsilon=${epsilon} --s=${s} --trial=\$SLURM_ARRAY_TASK_ID"
           
           echo "Submitted array job: ${job_name}"
           sleep 2
       done
   done
   ```

3. Submit the job:
   ```bash
   bash submit.sh
   ```

### Output
The execution scripts will automatically create two subdirectories within each benchmark folder:
* `logfiles/`: Contains the standard output and error logs (`.out`, `.err`) for each array task.
* `results/`: Contains the generated CSV files with the optimization results, including computation times, objective values, and estimated violation probabilities.

## Citation

If you find this repository helpful or use our code in your research, please consider citing our paper:

```bibtex
@article{abcdedfghijk,
  title={Decision-Scaled Scenario Approach for Rare Chance-Constrained Optimization},
  author={Choi, Jaeseok and Deo, Anand and Lagoa, Constantino and Subramanyam, Anirudh},
  journal={arXiv preprint},
  year={2026}
}
```

For any questions or support, please open an issue in the repository.