#!/bin/bash
#SBATCH --partition=sla-prio
#SBATCH --account=azs7266_sc
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --mem=32GB
#SBATCH --time=00:30:00
#SBATCH --job-name=precompile_all
#SBATCH --output=precompile_%j.out

# 1. Load modules 
module purge
module load julia/1.11.2 gurobi

# 2. Set directory for packages
export JULIA_DEPOT_PATH=/storage/home/jxc6747/.julia/depot

# 3. Set Mosek environment variables
export MOSEK_HOME=$HOME/mosek/11.0
export MOSEKLM_LICENSE_FILE=$HOME/mosek.lic

# 4. Instantiate and Precompile
# Based on Project.toml/Manifest.toml in root folder.
julia --project=. -e 'import Pkg; Pkg.instantiate(); Pkg.precompile()'

echo "Precompilation complete!"