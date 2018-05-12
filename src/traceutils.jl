function recurse(f, call)
    f(call)
    map(call.children) do child
        recurse(f, child)
    end
end

function recurse(f, trace::Trace)
    @assert isempty(trace.stack)
    @assert length(trace.current) == 1

    recurse(f, trace.current[1])
end

"""
    flatten(t::Trace)

Helper function that flattens a trace generated by `concolic_execution` so that only the leaf nodes are present.
"""
function flatten(t::Trace)
    stream = Tuple{Any, Any, Tuple}[]
    recurse(t) do call
        if isempty(call.children)
            push!(stream, (call.f, call.retval, call.args))
        end
        return
    end
    return stream
end

function filter(t::Trace)
    stream = Tuple{Any, Any, Tuple}[]
    recurse(t) do call
        if isempty(call.children) && any(a->isa(a,Sym), call.args)
            push!(stream, (call.f, call.retval, call.args))
        end
        return
    end
    return stream
end


const FUNCTIONS_TO_IGNORE =(
    Base.one,
    Base.zero,
    assert,
    prove,
)

"""
    verify(trace, merciless=false)

Use `verify(trace, true)` to see built-ins that cause concrete execution
"""
function verify(t::Trace, merciless=false)
    @assert isempty(t.stack)
    @assert length(t.current) == 1
    topmost = t.current[1].f
    recurse(t) do call
        if any(a->isa(a, Sym), call.args) && !(call.retval isa Sym)
            if typeof(call.f) <: Core.Builtin && !merciless
                return
            end
            if call.f == topmost || call.f ∈ FUNCTIONS_TO_IGNORE
                return
            end
            # Not sure why these occur
            if call.retval isa Cassette.Unused
                return
            end
            @warn "Function $(call.f) did not propagate taint, $((call.retval, call.args))"
        end
        return
    end
    return nothing
end

function Base.print(io::IO, t::Trace)
    println(io, "Trace:")
    recurse(t) do call
        base = " "^call.depth
        write(io, base)
        print(io, call.retval)
        write(io, " <- ")
        println(io, call.f, call.args)
        return
    end
    return nothing
end
