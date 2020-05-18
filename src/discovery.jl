using Mocking: Mocking, @mock

"""
    timezone_names() -> Vector{String}

Returns a sorted list of all of the pre-computed time zone names.
"""
function timezone_names()
    names = String[]
    check = Tuple{String,String}[(TZData.COMPILED_DIR, "")]

    for (dir, partial) in check
        for filename in readdir(dir)
            startswith(filename, ".") && continue
            endswith(filename, ".jl") && continue

            path = joinpath(dir, filename)
            name = partial == "" ? filename : join([partial, filename], "/")

            if isdir(path)
                push!(check, (path, name))
            else
                push!(names, name)
            end
        end
    end

    return sort!(names)
end

"""
    all_timezones() -> Vector{TimeZone}

Returns all pre-computed `TimeZone`s.
"""
function all_timezones()
    results = TimeZone[]
    for name in timezone_names()
        push!(results, TimeZone(name, Class(:ALL)))
    end
    return results
end

"""
    all_timezones(criteria::Function) -> Vector{TimeZone}

Returns `TimeZone`s that match the given `criteria` function. The `criteria` function takes
two parameters: UTC transition (`DateTime`) and transition zone (`FixedTimeZone`).

## Examples

Find all time zones which contain an absolute UTC offset greater than 15 hours:

```julia
all_timezones() do dt, zone
    abs(zone.offset.std) > Dates.Second(Dates.Hour(15))
end
```

Determine all time zones which have a non-hourly daylight saving time offset:

```julia
all_timezones() do dt, zone
    zone.offset.dst % Dates.Second(Dates.Hour(1)) != 0
end
```
"""
function all_timezones(criteria::Function)
    results = TimeZone[]
    for tz in all_timezones()
        if isa(tz, FixedTimeZone)
            criteria(typemin(DateTime), tz) && push!(results, tz)
        else
            for t in tz.transitions
                if criteria(t.utc_datetime, t.zone)
                    push!(results, tz)
                    break
                end
            end
        end
    end
    return results
end

"""
    timezones_from_abbr(abbr) -> Vector{TimeZone}

Returns all `TimeZone`s that have the specified abbrevation
"""
function timezones_from_abbr end

function timezones_from_abbr(abbr::AbstractString)
    results = TimeZone[]
    for tz in all_timezones()
        if isa(tz, FixedTimeZone)
            tz.name == abbr && push!(results, tz)
        else
            for t in tz.transitions
                if t.zone.name == abbr
                    push!(results, tz)
                    break
                end
            end
        end
    end
    return results
end

"""
    timezone_abbrs -> Vector{String}

Returns a sorted list of all pre-computed time zone abbrevations.
"""
function timezone_abbrs()
    abbrs = Set{String}()
    for tz in all_timezones()
        if isa(tz, FixedTimeZone)
            push!(abbrs, tz.name)
        else
            for t in tz.transitions
                push!(abbrs, t.zone.name)
            end
        end
    end
    return sort!(collect(abbrs))
end


"""
    next_transition_instant(zdt::ZonedDateTime) -> Union{Tuple{DateTime, FixedTimeZone, FixedTimeZone}, Nothing}
    next_transition_instant(tz::TimeZone=localzone()) -> Union{Tuple{DateTime, FixedTimeZone, FixedTimeZone}, Nothing}

Determine the next instant at which a time zone transition occurs (typically
due to daylight-savings time). If no there exists no future transition then `nothing` will
be returned.

Returns the naive instant of the transition, and the fixed time zones active before and after
the transition.
"""
next_transition_instant

next_transition_instant(zdt::ZonedDateTime{FixedTimeZone}) = nothing

function next_transition_instant(zdt::ZonedDateTime{VariableTimeZone})
    tz = zdt.timezone

    # Determine the index of the transition which occurs after the UTC datetime specified
    index = searchsortedfirst(
        tz.transitions, DateTime(zdt, UTC),
        by=el -> isa(el, TimeZones.Transition) ? el.utc_datetime : el,
    )

    index <= length(tz.transitions) || return nothing

    utc_datetime = tz.transitions[index].utc_datetime
    from_zone = tz.transitions[index - 1].zone
    to_zone = tz.transitions[index].zone
    return (utc_datetime, from_zone, to_zone)
end

next_transition_instant(tz::TimeZone=localzone()) = next_transition_instant(@mock now(tz))


"""
    show_next_transition(io::IO=stdout, zdt::ZonedDateTime)
    show_next_transition(io::IO=stdout, tz::TimeZone=localzone())

Display useful information about the next time zone transition (typically
due to daylight-savings time). Information displayed includes:

* Transition Date: the local date at which the transition occurs (2018-10-28)
* Local Time Change: the way the local clock with change (02:00 falls back to 01:00) and
    the direction of the change ("Forward" or "Backward")
* Offset Change: the standard offset and DST offset that occurs before and after the
   transition
* Transition From: the instant before the transition occurs
* Transition To: the instant after the transition occurs

```julia
julia> show_next_transition(ZonedDateTime(2018, 8, 1, tz"Europe/London"))
Transition Date:   2018-10-28
Local Time Change: 02:00 → 01:00 (Backward)
Offset Change:     UTC+0/+1 → UTC+0/+0
Transition From:   2018-10-28T01:59:59.999+01:00 (BST)
Transition To:     2018-10-28T01:00:00.000+00:00 (GMT)

julia> show_next_transition(ZonedDateTime(2011, 12, 1, tz"Pacific/Apia"))
Transition Date:   2011-12-30
Local Time Change: 00:00 → 00:00 (Forward)
Offset Change:     UTC-11/+1 → UTC+13/+1
Transition From:   2011-12-29T23:59:59.999-10:00
Transition To:     2011-12-31T00:00:00.000+14:00
```
"""
show_next_transition

function show_next_transition(io::IO, zdt::ZonedDateTime{FixedTimeZone})
    @warn "No transitions exist in time zone $(timezone(zdt))"
    return
end

function show_next_transition(io::IO, zdt::ZonedDateTime{VariableTimeZone})
    tran_info = next_transition_instant(zdt)

    if tran_info === nothing
        @warn "No transition exists in $(timezone(zdt)) after: $zdt"
        return
    end

    instant, from_zone, to_zone = tran_info
    epsilon = eps(instant)
    from = ZonedDateTime(instant - epsilon, from_zone; from_utc=true)
    to = ZonedDateTime(instant, to_zone; from_utc=true)
    direction = value(to_zone.offset - from_zone.offset) < 0 ? "Backward" : "Forward"
    instant_in_from = ZonedDateTime(instant, from_zone; from_utc=true)

    function zdt_format(zdt)
        zone = current_zone(zdt)
        name_suffix = zone.name
        !isempty(name_suffix) && (name_suffix = string(" (", name_suffix, ")"))
        string(
            Dates.format(zdt, dateformat"yyyy-mm-ddTHH:MM:SS.sss"),
            zone.offset,  # Note: "zzz" will not work in the format above as is
            name_suffix,
        )
    end
    function time_format(zdt)
        Dates.format(zdt, second(zdt) == 0 ? dateformat"HH:MM" : dateformat"HH:MM:SS")
    end

    println(io, "Transition Date:   ", Dates.format(instant, dateformat"yyyy-mm-dd"))
    println(io, "Local Time Change: ", time_format(instant_in_from), " → ", time_format(to), " (", direction, ")")
    println(io, "Offset Change:     ", repr("text/plain", from_zone.offset), " → ", repr("text/plain", to_zone.offset))
    println(io, "Transition From:   ", zdt_format(from))
    println(io, "Transition To:     ", zdt_format(to))

end

function show_next_transition(io::IO, tz::TimeZone=localzone())
    show_next_transition(io, @mock now(tz))
end

show_next_transition(x) = show_next_transition(stdout, x)
