using JuMP, Distributions, LinearAlgebra, Random, MosekTools

"""
Classical Scenario Approach for Norm Optimization.
"""
function basic_sp(params, ξ)
    model = direct_model(Mosek.Optimizer())
    set_optimizer_attribute(model, "MSK_IPAR_LOG", 10)
    set_optimizer_attribute(model, "MSK_DPAR_OPTIMIZER_MAX_TIME", 3600.0)
    set_optimizer_attribute(model, "MSK_IPAR_NUM_THREADS", Threads.nthreads())

    n = params.n
    m = params.m

    # Decision variables
    @variable(model, x[1:n] >= 0)

    # Objective function: Maximize sum of x
    @objective(model, Max, sum(x))

    num_scenarios = size(ξ, 3)
    
    # Chance constraint approximated by scenarios
    for k in 1:num_scenarios
        for i in 1:m
            @constraint(model, [10.0; [ξ[i, j, k] * x[j] for j in 1:n]] in SecondOrderCone())
        end
    end

    optimize!(model)
    @info "Training sample size: $(num_scenarios)"

    status = termination_status(model)
    if !(status in (MOI.INFEASIBLE, MOI.NO_SOLUTION))
        obj_val = objective_value(model)
        sol = value.(x)
        return (sol, obj_val, MOI.get(model, MOI.SolveTimeSec()))
    else
        @warn "No valid solution (status: $status)"
        return (nothing, nothing, MOI.get(model, MOI.SolveTimeSec()))
    end
end

"""
Scaled Scenario Approach for Norm Optimization.
"""
function scaled_sp(s, params, ξ)
    model = direct_model(Mosek.Optimizer())
    set_optimizer_attribute(model, "MSK_IPAR_LOG", 10)
    set_optimizer_attribute(model, "MSK_DPAR_OPTIMIZER_MAX_TIME", 3600.0)
    set_optimizer_attribute(model, "MSK_IPAR_NUM_THREADS", Threads.nthreads())

    n = params.n
    m = params.m

    # Decision variables
    @variable(model, x[1:n] >= 0)

    # Objective function: Maximize sum of x
    @objective(model, Max, sum(x))

    num_scenarios = size(ξ, 3)
    rhs_val = 10.0 / s

    # Scaled Chance constraint: s^2 * sum_j (z_ij * x_j)^2 <= 100 <=> || Z_i .* x ||_2 <= 10/s
    for k in 1:num_scenarios
        for i in 1:m
            @constraint(model, [rhs_val; [ξ[i, j, k] * x[j] for j in 1:n]] in SecondOrderCone())
        end
    end

    optimize!(model)
    @info "Training sample size: $(num_scenarios)"

    status = termination_status(model)
    if !(status in (MOI.INFEASIBLE, MOI.NO_SOLUTION))
        obj_val = objective_value(model)
        sol = value.(x)
        return (sol, obj_val, MOI.get(model, MOI.SolveTimeSec()))
    else
        @warn "No valid solution (status: $status)"
        return (nothing, nothing, MOI.get(model, MOI.SolveTimeSec()))
    end
end

"""
Wrapper for Scaled Scenario Approach.
"""
function scaled_sa(ε, β, α, s, params, ξ)
    n_vars = params.n
    λ = s^α
    N_λ = ceil(Int, (2 / (ε^(1 / λ))) * (log(1 / β) + n_vars))
    ξ_training = ξ[:, :, 1:N_λ]

    @info "Training sample size: $(size(ξ_training, 3))"
    optimal_solution, optimal_value, cpu_time = scaled_sp(s, params, ξ_training)
    return optimal_solution, optimal_value, cpu_time
end

"""
Evaluate out-of-sample violation probability via Monte Carlo.
"""
function evaluate_solution(solution, params, num_samples, batch_size=10^7)
    if solution === nothing
        return NaN
    end
    x = solution
    n = params.n
    m = params.m

    num_batches = ceil(Int, num_samples / batch_size)
    actual_samples = num_batches * batch_size

    # Base distribution for generating columns (mean 0, handled below)
    dist = MvNormal(zeros(m), params.Σ)
    atomic_violations = Threads.Atomic{Int}(0)

    buffers = [Matrix{Float64}(undef, m, n) for _ in 1:Threads.nthreads()]

    Threads.@threads for _ in 1:num_batches
        tid = Threads.threadid()
        Z_buf = buffers[tid]
        
        local_violations = 0
        
        for b in 1:batch_size
            rand!(dist, Z_buf)
            
            is_violated = false
            for i in 1:m
                val = 0.0
                for j in 1:n
                    val += ((Z_buf[i, j] + params.μ[j]) * x[j])^2
                end
                if val > 100.0
                    is_violated = true
                    break
                end
            end
            
            if is_violated
                local_violations += 1
            end
        end
        Threads.atomic_add!(atomic_violations, local_violations)
    end
    
    return atomic_violations[] / actual_samples
end

"""
Generate a pool of ξ scenarios. 
Each scenario is an m x n matrix where each column j ~ MvNormal(μ_j, Σ).
"""
function generate_xi(num_samples, params)
    n = params.n
    m = params.m
    
    dist = MvNormal(zeros(m), params.Σ)
    samples_pool = Array{Float64, 3}(undef, m, n, num_samples)
    flat_matrix = reshape(samples_pool, m, n * num_samples)
    rand!(dist, flat_matrix)

    Threads.@threads for k in 1:num_samples
        for j in 1:n
            μ_j = params.μ[j]
            for i in 1:m
                samples_pool[i, j, k] += μ_j
            end
        end
    end
    
    return samples_pool
end

