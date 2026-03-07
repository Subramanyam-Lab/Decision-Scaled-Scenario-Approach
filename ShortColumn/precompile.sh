#!/bin/bash
#SBATCH --partition=sla-prio
#SBATCH --account=azs7266_sc
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --mem=16GB
#SBATCH --time=00:30:00
#SBATCH --job-name=setup_shortcolumn
#SBATCH --output=setup_%j.out

# 1. Load modules
module load julia/1.11.2

# 2. Set directory for packages (HPC Depot path)
export JULIA_DEPOT_PATH=/storage/home/jxc6747/.julia/depot

# 3. Set Mosek environment variables
export MOSEK_HOME=$HOME/mosek/11.0
export MOSEKLM_LICENSE_FILE=$HOME/mosek.lic

# 4. Compile (sbatch precompile.sh)
julia --project=. -e 'using Pkg; Pkg.add(["ArgParse", "CSV", "DataFrames", "Distributions", "JuMP", "Mosek", "MosekTools", "CPUTime"]); Pkg.precompile()'

echo "Precompilation complete!"