using ArgParse, DataFrames, CSV, JuMP, Random, Distributions, MosekTools, LinearAlgebra
include("Norm_Opt_functions.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--epsilon"
            help = "epsilon value"
            arg_type = Float64
            required = true
        "--s"
            help = "s value (Note: script uses s^(1/α) internally if > 1.0)"
            arg_type = Float64
            required = true
        "--trial"
            help = "trial number"
            arg_type = Int
            required = true
    end
    return parse_args(s)
end

function main()
    @warn"=== Norm_Opt_run.jl ==="
    # Mosek Optimizer Warmup
    warmup_model = Model(Mosek.Optimizer)
    @variable(warmup_model, _x >= 0)
    @objective(warmup_model, Max, _x)
    @warn">> warmup "
    optimize!(warmup_model)
    @warn">> warmup done: ", termination_status(warmup_model)
    
    args = parse_commandline()

    # Experiment parameters for Norm Optimization
    n_val = 5
    m_val = 3
    
    # mean vector:  j/n
    μ_val = [j / n_val for j in 1:n_val]
    
    # covariance
    Σ_val = fill(0.5, m_val, m_val)
    for i in 1:m_val
        Σ_val[i, i] = 1.0
    end

    params = (
        n = n_val,
        m = m_val,
        μ = μ_val,
        Σ = Σ_val
    )
    
    # Parameters from command line
    ε = args["epsilon"]
    s = args["s"]
    trial = args["trial"]

    # Tail index for Multivariate Normal distribution
    α = 2.0
    β = 0.05

    # Number of samples for out-of-sample violation evaluation
    num_eval_samples = ceil(Int, 10^4 / ε)
    
    # Set seed for reproducibility for each trial
    Random.seed!(trial)
    
    # Generate a large pool of training samples once
    n_vars = params.n
    N_max = ceil(Int, (2 / ε) * (log(1 / β) + n_vars))
    ξ_pool = generate_xi(N_max, params)

    results = []
    
    #actual s
    actual_s = s == 1.0 ? 1.0 : s^(1 / α)

    if s == 1.0
        # Basic Scenario Approach case
        N = ceil(Int, (2 / ε) * (log(1 / β) + n_vars))
        ξ_training = ξ_pool[:, :, 1:N]
        optimal_solution_basic, optimal_value_basic, elapsed_basic_sp = basic_sp(params, ξ_training)
        violation_rate_basic = evaluate_solution(optimal_solution_basic, params, num_eval_samples)
        
        push!(results, (ε, 1.0, "CC", optimal_value_basic, elapsed_basic_sp, violation_rate_basic))
    else
        # Scaled Scenario Approach case 
        optimal_solution_scaled, optimal_value_scaled, elapsed_scaled_sa = scaled_sa(ε, β, α, actual_s, params, ξ_pool)
        violation_rate_scaled = evaluate_solution(optimal_solution_scaled, params, num_eval_samples)
        
        push!(results, (ε, s, "SSP", optimal_value_scaled, elapsed_scaled_sa, violation_rate_scaled))
    end
    
    # Save results to DataFrame
    res = DataFrame(
        epsilon = [r[1] for r in results],
        s = [r[2] for r in results],
        method = [r[3] for r in results],
        objective_value = [r[4] for r in results],
        cpu_time = [r[5] for r in results],
        violation_rate = [r[6] for r in results]
    )

    # Export to CSV
    output_dir = "results"
    mkpath(output_dir)
    output_file = joinpath(output_dir, "result_e$(ε)_s$(s)_t$(trial).csv")
    CSV.write(output_file, res)
    @info "Results saved to $output_file"
end

main()