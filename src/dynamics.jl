abstract type AbstractTemporalStructureTrait end
struct TimeVarying <: AbstractTemporalStructureTrait end
struct TimeInvariant <: AbstractTemporalStructureTrait end

"""
    temporal_structure_trait(object)

Returns an `AbstractTemporalStructureTrait` to signal if this object (e.g. strategy or dynamics) is
time varying or not.
"""
function temporal_structure_trait end

"""
    dynamics(state, actions[, t]).

Computes the next state for a collecition of player `actions` applied to the multi-player \
`dynamics`.
"""
abstract type AbstractDynamics end

"Number of states."
function state_dim end

"""
    control_dim(sys)

Returns the total number of control inputs.

    control_dim(sys, i)

Returns the number of control inputs for player i.
"""
function control_dim end

"Returns a tuple `(lb, ub)` of the lower and upper bound of the state vector."
function state_bounds end

"Returns a tuple `(lb, ub)` of the lower and upper bound of the control vector."
function control_bounds end

"The number of players that control this sytem."
function num_players end

"The number of time steps the dynamics are valid for."
function horizon end

function get_constraints_from_box_bounds(bounds)
    function (y)
        mapreduce(vcat, [(bounds.lb, 1), (bounds.ub, -1)]) do (bound, sign)
            # drop constraints for unbounded variables
            mask = (!isinf).(bound)
            sign * (y[mask] - bound[mask])
        end
    end
end

#=== generic utils ===#

"""
Simulates a `strategy` by evolving the `dynamics` for `T` time steps starting from state `x1` and
applying the inputs dictated by the strategy.

Kwargs:

- `get_info` is a callback `(γ, x, t) -> info` that can be passed to extract additional info from \
the strategy `γ` for each rollout state `x` and time `t`.
- `skip_last_strategy_call = false`. Setting this to true avoids calling the strategy on the last \
time step because this input will never be applied anyway. In that case, us will have one element \
less than xs.

Returns a tuple of collections over states `xs`, inputs `us`, and extra information `infos`.
"""
function rollout(
    dynamics,
    strategy,
    x1,
    T = horizon(dynamics);
    get_info = (γ, x, t) -> nothing,
    skip_last_strategy_call = false,
)
    xs = sizehint!([x1], T)
    us = sizehint!([strategy(x1, 1)], T)
    infos = sizehint!([get_info(strategy, x1, 1)], T)

    time_steps = 1:(T - 1)

    for tt in time_steps
        xp = dynamics(xs[tt], us[tt], tt)
        push!(xs, xp)

        if skip_last_strategy_call && tt == lastindex(time_steps)
            break
        end

        up = strategy(xp, tt + 1)
        push!(us, up)
        infop = get_info(strategy, xs[tt], tt + 1)
        push!(infos, infop)
    end

    (; xs, us, infos)
end
