using ArgParse, DataFrames, CSV, JuMP, Random, Distributions, MosekTools, CPUTime
include("ShortColumn_functions.jl")

function parse_commandline()
    s = ArgParseSettings()
    @add_arg_table! s begin
        "--epsilon"
            help = "epsilon value"
            arg_type = Float64
            required = true
        "--s"
            help = "s value"
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
    @warn"=== ShortColumn_run.jl ==="
    warmup_model = Model(Mosek.Optimizer)
    @variable(warmup_model, _x >= 0)
    @objective(warmup_model, Max, _x)
    @warn">> warmup "
    optimize!(warmup_model)
    @warn">> warmup done: ", termination_status(warmup_model)
    args = parse_commandline()

    # Experiment parameters for Short Column Design
    params = (
        C_Y = 5, 
        L_w = 5.0,
        L_h = 15.0,
        μ_ξ = [6, 7.5],
        Σ_ξ = [0.4 0.2; 0.2 0.4]
    )
    
    # Parameters from command line
    ε = args["epsilon"]
    s = args["s"]
    trial = args["trial"]

    # Tail index for Normal distribution
    α = 2.0
    β = 0.01

    # Number of samples for violation evaluation
    m = ceil(Int, 10^4 / ε)
    
    # Set seed for reproducibility for each trial
    Random.seed!(trial)
    
    # Generate a large pool of samples once
    n_vars = 2
    N_max = ceil(Int, (2/ε) * (log(1/β) + n_vars))
    ξ_pool = generate_xi(N_max, params.μ_ξ, params.Σ_ξ)

    results = []
    actual_s = s == 1.0 ? 1.0 : s^(1/α)

    if s == 1.0
        # Basic Scenario Approach case
        N = ceil(Int, (2/ε) * (log(1/β) + n_vars))
        ξ_training = ξ_pool[:, 1:N]
        optimal_solution_basic, optimal_value_basic, elapsed_basic_sp = basic_sp(params, ξ_training)
        violation_rate_basic = evaluate_solution(optimal_solution_basic, params, m)
        
        push!(results, (ε, 1.0, "CC", optimal_value_basic, elapsed_basic_sp, violation_rate_basic))
    else
        # Scaled Scenario Approach case 
        optimal_solution_scaled, optimal_value_scaled, elapsed_scaled_sa = scaled_sa(ε, β, α, actual_s, params, ξ_pool)
        violation_rate_scaled = evaluate_solution(optimal_solution_scaled, params, m)
        
        push!(results, (ε, s, "SSP", optimal_value_scaled, elapsed_scaled_sa, violation_rate_scaled))
    end
    
    # Save results
    res = DataFrame(
        epsilon = [r[1] for r in results],
        s = [r[2] for r in results],
        method = [r[3] for r in results],
        objective_value = [r[4] for r in results],
        cpu_time = [r[5] for r in results],
        violation_rate = [r[6] for r in results]
    )

    output_dir = "results"
    mkpath(output_dir)
    output_file = joinpath(output_dir, "result_e$(ε)_s$(s)_t$(trial).csv")
    CSV.write(output_file, res)
end

main()