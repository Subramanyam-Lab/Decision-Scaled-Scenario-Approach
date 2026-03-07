#!/bin/bash

module load julia
module load gurobi

# Set directory for packages
export JULIA_DEPOT_PATH=/storage/home/jxc6747/.julia/depot

# Compile packages in project.toml
julia --project -e 'using Pkg; Pkg.instantiate()'
julia --project -e 'using Pkg; Pkg.precompile()'