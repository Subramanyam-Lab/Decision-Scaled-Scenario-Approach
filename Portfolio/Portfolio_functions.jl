using JuMP, Gurobi, Distributions, LinearAlgebra, CPUTime, Random

"""
Classical Scenario Approach.
"""
function basic_sp(n, μ, η, ξ)
    model = direct_model(Gurobi.Optimizer())

    set_time_limit_sec(model, 3600.0)
    set_optimizer_attribute(model, "Threads", Threads.nthreads())

    @variable(model, x[1:n] >= 0)
    @objective(model, Max, dot(μ, x))

    num_scenarios = size(ξ, 1)
    for i in 1:num_scenarios
        @constraint(model, sum(ξ[i, j] * x[j] for j in 1:n) <= η)
    end

    optimize!(model)
    solve_time = MOI.get(model, MOI.SolveTimeSec())
    @info "Training sample size: $(size(ξ,1))"
    if termination_status(model) == MOI.OPTIMAL
        return (value.(x), objective_value(model), solve_time)
    else
        return (nothing, nothing, solve_time)
    end
end

"""
Scaled Scenario Approach.
"""
function scaled_sp(s, n, μ, η, ξ)
    model = direct_model(Gurobi.Optimizer())

    set_time_limit_sec(model, 3600.0)
    set_optimizer_attribute(model, "Threads", Threads.nthreads())

    @variable(model, x[1:n] >= 0)
    @objective(model, Max, dot(μ, x))

    num_scenarios = size(ξ, 1)
    for i in 1:num_scenarios
        @constraint(model, sum(ξ[i, j] * x[j] for j in 1:n) <= η/s)
    end
  
    optimize!(model)
    solve_time = MOI.get(model, MOI.SolveTimeSec())
    
    if termination_status(model) == MOI.OPTIMAL
        return (value.(x), objective_value(model), solve_time)
    else
        return (nothing, nothing, solve_time)
    end
end

"""
Solve Scaled Scenario Approach.
"""
function scaled_sa(ε, β, α, s, n, μ, η, ξ)
    λ = s^α
    N_λ = ceil(Int, (2/(ε^(1 / λ))) * (log(1/β) + n))
    ξ_training = ξ[1:N_λ, :]

    @info "Training sample size: $(size(ξ_training, 1))"
    optimal_solution, optimal_value, cpu_time = scaled_sp(s, n, μ, η, ξ_training)
    return optimal_solution, optimal_value, cpu_time
end

"""
Compute the Violation Probability.
"""
function evaluate_solution(solution, shapes, scales, n, η, num_samples, batch_size=10^7)
    if solution === nothing
        return NaN
    end

    num_batches = ceil(Int, num_samples / batch_size)
    actual_samples = num_batches * batch_size
    
    dists = [Weibull(shapes[j], scales[j]) for j in 1:n]
    atomic_violations = Threads.Atomic{Int}(0)

    Threads.@threads for _ in 1:num_batches
        local_violations = 0
        
        for i in 1:batch_size
            val = 0.0
            for j in 1:n
                val += solution[j] * rand(dists[j])
            end
            
            if val > η
                local_violations += 1
            end
        end
        Threads.atomic_add!(atomic_violations, local_violations)
    end
    
    return atomic_violations[] / actual_samples
end

"""
Generate Random Sample. If you want different Distributions revise it.
"""
function generate_xi(num_samples, shapes, scales, n)
    xi = Matrix{Float64}(undef, num_samples, n)
    dists = [Weibull(shapes[j], scales[j]) for j in 1:n] 

    #Multi Threading
    Threads.@threads for i in 1:num_samples
        for j in 1:n
            xi[i, j] = rand(dists[j])
        end
    end
    
    return xi
end
