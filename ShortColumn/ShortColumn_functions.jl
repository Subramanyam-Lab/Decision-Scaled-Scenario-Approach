using JuMP, Distributions, LinearAlgebra, Random, MosekTools

"""
Classical Scenario Approach for Short Column Design.
"""
function basic_sp(params, ξ)
    model = direct_model(Mosek.Optimizer())
    set_optimizer_attribute(model, "MSK_IPAR_LOG", 10)
    set_optimizer_attribute(model, "MSK_DPAR_OPTIMIZER_MAX_TIME", 3600.0)
    set_optimizer_attribute(model, "MSK_IPAR_NUM_THREADS", Threads.nthreads())

    # Decision variables with bounds
    @variable(model, x_w_tilde >= log(params.L_w))
    @variable(model, x_h_tilde >= log(params.L_h))

    # Objective function
    @objective(model, Min, x_w_tilde + x_h_tilde)

    num_scenarios = size(ξ, 2)

    @variable(model, u_M[1:num_scenarios] >= 0)
    @variable(model, u_F[1:num_scenarios] >= 0)

    const_M = log(4 / params.C_Y)
    const_F = log(1 / (params.C_Y^2))

    # Chance constraint approximated by scenarios
    for i in 1:num_scenarios
        z_M = ξ[1, i]
        z_F = ξ[2, i]

        a1 = const_M + z_M - (x_w_tilde + 2 * x_h_tilde)
        @constraint(model, [a1, 1, u_M[i]] in MOI.ExponentialCone())

        a2 = const_F + 2 * z_F - 2 * (x_w_tilde + x_h_tilde)
        @constraint(model, [a2, 1, u_F[i]] in MOI.ExponentialCone())

        @constraint(model, u_M[i] + u_F[i] <= 1)
    end

    optimize!(model)
    solve_time = MOI.get(model, MOI.SolveTimeSec())
    @info "Training sample size: $(num_scenarios)"

    status = termination_status(model)
    if !(status in (MOI.INFEASIBLE, MOI.NO_SOLUTION))
        obj_val = objective_value(model)
        sol = [value(x_w_tilde), value(x_h_tilde)]
        return (sol, obj_val, MOI.get(model, MOI.SolveTimeSec()))
    else
        @warn "No valid solution (status: $status)"
        return (nothing, nothing, MOI.get(model, MOI.SolveTimeSec()))
    end
end

"""
Scaled Scenario Approach for Short Column Design.
"""
function scaled_sp(s, params, ξ)
    model = direct_model(Mosek.Optimizer())
    set_optimizer_attribute(model, "MSK_IPAR_LOG", 10)
    set_optimizer_attribute(model, "MSK_DPAR_OPTIMIZER_MAX_TIME", 3600.0)
    set_optimizer_attribute(model, "MSK_IPAR_NUM_THREADS", Threads.nthreads())

    # Decision variables with bounds: x_hat = x_tilde / s , x_tilde = s x_hat
    @variable(model, x_w_hat >= log(params.L_w) / s)
    @variable(model, x_h_hat >= log(params.L_h) / s)

    # Objective function
    @objective(model, Min, x_w_hat + x_h_hat)

    num_scenarios = size(ξ, 2)

    @variable(model, u_M[1:num_scenarios] >= 0)
    @variable(model, u_F[1:num_scenarios] >= 0)

    const_M = log(4 / params.C_Y)
    const_F = log(1 / (params.C_Y^2))

    # Chance constraint approximated by scenarios
    for i in 1:num_scenarios
        z_M = ξ[1, i]
        z_F = ξ[2, i]

        a1 = const_M + z_M - (x_w_hat + 2 * x_h_hat)
        @constraint(model, [a1, 1, u_M[i]] in MOI.ExponentialCone())

        a2 = const_F + 2 * z_F - 2 * (x_w_hat + x_h_hat)
        @constraint(model, [a2, 1, u_F[i]] in MOI.ExponentialCone())

        @constraint(model, u_M[i] + u_F[i] <= 1)
    end

    optimize!(model)
    solve_time = MOI.get(model, MOI.SolveTimeSec())
    @info "Training sample size: $(num_scenarios)"

    status = termination_status(model)
    if !(status in (MOI.INFEASIBLE, MOI.NO_SOLUTION))
        obj_val = objective_value(model) * s
        sol = [value(x_w_hat)* s, value(x_h_hat)* s]
        return (sol, obj_val, MOI.get(model, MOI.SolveTimeSec()))
    else
        @warn "No valid solution (status: $status)"
        return (nothing, nothing, MOI.get(model, MOI.SolveTimeSec()))
    end
end


function scaled_sa(ε, β, α, s, params, ξ)
    n_vars = 2
    λ = s^α
    N_λ = ceil(Int, (2 / (ε^(1 / λ))) * (log(1 / β) + n_vars))
    ξ_training = ξ[:, 1:N_λ]

    @info "Training sample size: $(size(ξ_training, 2))"
    optimal_solution, optimal_value, cpu_time = scaled_sp(s, params, ξ_training)
    return optimal_solution, optimal_value, cpu_time
end

function evaluate_solution(solution, params, num_samples, batch_size=10^7)
    if solution === nothing
        return NaN
    end
    x_w, x_h = solution[1], solution[2]

    const_M = log(4 / params.C_Y)
    const_F = log(1 / (params.C_Y^2))

    num_batches = ceil(Int, num_samples / batch_size)
    actual_samples = num_batches * batch_size

    dist = MvNormal(params.μ_ξ, params.Σ_ξ)  
    atomic_violations = Threads.Atomic{Int}(0)

    buffers = [Matrix{Float64}(undef, 2, batch_size) for _ in 1:Threads.nthreads()]

    Threads.@threads for _ in 1:num_batches
        tid = Threads.threadid()
        local_batch_samples = buffers[tid]

        rand!(dist, local_batch_samples)
        
        local_violations = 0
        
        @inbounds @simd for i in 1:batch_size
            z_M = local_batch_samples[1, i]
            z_F = local_batch_samples[2, i]

            a1 = const_M + z_M - (x_w + 2 * x_h)
            a2 = const_F + 2 * z_F - 2 * (x_w + x_h)

            if exp(a1) + exp(a2) > 1.0
                local_violations += 1
            end
        end
        Threads.atomic_add!(atomic_violations, local_violations)
    end
    
    return atomic_violations[] / actual_samples
end

function generate_xi(num_samples, μ_ξ, Σ_ξ)
    dist = MvNormal(μ_ξ, Σ_ξ)
    return rand(dist, num_samples)
end