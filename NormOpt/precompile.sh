#!/bin/bash
#SBATCH --partition=sla-prio
#SBATCH --account=azs7266_sc
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --mem=16GB
#SBATCH --time=00:30:00
#SBATCH --job-name=precompile_normopt
#SBATCH --output=precompile_%j.out

# 1. Load modules
module load julia/1.11.2

# 2. Set directory for packages
export JULIA_DEPOT_PATH=/storage/home/jxc6747/.julia/depot

# 3. Set Mosek environment variables
export MOSEK_HOME=$HOME/mosek/11.0
export MOSEKLM_LICENSE_FILE=$HOME/mosek.lic

# 4. Add packages and precompile (sbatch precompile.sh로 실행하기)
julia --project=. -e 'using Pkg; Pkg.add(["ArgParse", "CSV", "DataFrames", "Distributions", "JuMP", "Mosek", "MosekTools"]); Pkg.precompile()'

echo "Precompilation complete!"