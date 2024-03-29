function to_blockvector(block_dimensions)
    function (data)
        BlockArrays.BlockArray(data, block_dimensions)
    end
end

function to_vector_of_vectors(vector_dimension)
    function (z)
        reshape(z, vector_dimension, :) |> eachcol .|> collect
    end
end

function to_vector_of_blockvectors(block_dimensions)
    vector_dimension = sum(block_dimensions)
    function (z)
        z |> to_vector_of_vectors(vector_dimension) .|> to_blockvector(block_dimensions) |> collect
    end
end

"""
Convert a joint trajectory into a collection of single-player trajectories.

The inverse of `stack_trajectories`.
"""
function unstack_trajectory(
    trajectory,
    player_indices = 1:BlockArrays.blocklength(trajectory.us[begin]),
)
    (; xs, us) = trajectory
    map(player_indices) do ii
        xs_single = map(x -> x[BlockArrays.Block(ii)], xs)
        us_single = map(u -> u[BlockArrays.Block(ii)], us)
        (; xs = xs_single, us = us_single)
    end
end

"""
Convert a variable number of single-player trajectories to a single joint-trajectory by
block-stacking them.

The inverse of `unstack_trajectories`.
"""
function stack_trajectories(single_player_trajectories)
    xs = map((t.xs for t in single_player_trajectories)...) do x...
        mortar([x...])
    end
    us = map((t.us for t in single_player_trajectories)...) do u...
        mortar([u...])
    end
    (; xs, us)
end

"""
Convert a trajectory in `(; xs, us)` representation into a single "flat" vector `z`.

The inverse of `unflatten_trajectory`.
"""
function flatten_trajectory(trajectory)
    (; xs, us) = trajectory
    Iterators.map(xs, us) do x, u
        [x; u]
    end |> Iterators.flatten |> collect
end

"""
Convert a trajectory in flat `z` representation into a `(; xs, us)` NamedTuple of vector of vectors.

The inverse of `flatten_trajectory`.
"""
function unflatten_trajectory(z, state_dimension, control_dimension)
    Z = reshape(z, state_dimension + control_dimension, :)
    X = @view Z[1:state_dimension, :]
    U = @view Z[(state_dimension + 1):end, :]
    xs = eachcol(X) .|> collect
    us = eachcol(U) .|> collect
    (; xs, us)
end
