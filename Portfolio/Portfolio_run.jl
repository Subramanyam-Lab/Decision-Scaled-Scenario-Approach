using ArgParse, DataFrames, CSV, JuMP, Gurobi, Random, Distributions
include("Portfolio_functions.jl")

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
    warmup_model = Model(Gurobi.Optimizer)
    @variable(warmup_model, _x >= 0)
    @objective(warmup_model, Max, _x)
    optimize!(warmup_model)

    args = parse_commandline()
    
    # Experiment parameters
    n = 20

    rng_params = MersenneTwister(12345)
    μ = rand(rng_params, Uniform(1, 3), n)
    
    weibull_shapes = fill(0.9, n)
    weibull_scales = rand(rng_params, Uniform(2, 10), n)

    α = minimum(weibull_shapes)
    η = 1000.0
    β = 0.01

    # Parameters from command line
    ε = args["epsilon"]
    s = args["s"]
    trial = args["trial"]

    # Number of samples for violation evaluation
    m = ceil(Int, 10^4 / ε)

    # Run single experiment
    Random.seed!(trial)
    
    # Generate ξ with respect to ε
    N = ceil(Int, (2/ε) * (log(1/β) + n))
    ξ = generate_xi(N, weibull_shapes, weibull_scales, n)

    results = []
    
    actual_s = s == 1.0 ? 1.0 : s^(1/α)

    if s == 1.0
        # basic_sp case
        optimal_solution_basic, optimal_value_basic, elapsed_basic_sp = basic_sp(n, μ, η, ξ)

        violation_rate_basic = evaluate_solution(optimal_solution_basic, weibull_shapes, weibull_scales, n, η, m)
        
        push!(results, (ε, 1.0, "CC", optimal_value_basic, elapsed_basic_sp, 
              violation_rate_basic, optimal_solution_basic))
    else
        # scaled_sa case 
        optimal_solution_scaled, optimal_value_scaled, elapsed_scaled_sa = scaled_sa(ε, β, α, actual_s, n, μ, η, ξ)

        violation_rate_scaled = evaluate_solution(optimal_solution_scaled, weibull_shapes, weibull_scales, n, η, m)
        
        push!(results, (ε, s, "SSP", optimal_value_scaled, elapsed_scaled_sa, 
              violation_rate_scaled, optimal_solution_scaled))
    end
    
    
    # Save results
    res = DataFrame(
        epsilon = [r[1] for r in results],
        s = [r[2] for r in results],
        method = [r[3] for r in results],
        objective_value = [r[4] for r in results],
        cpu_time = [r[5] for r in results],
        violation_rate = [r[6] for r in results])

    output_file = "results/result_e$(ε)_s$(s)_t$(trial).csv"
    CSV.write(output_file, res)
end

main()