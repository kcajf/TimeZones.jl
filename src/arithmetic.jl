import Base.Broadcast: broadcasted

# ZonedDateTime arithmetic
Base.:(+)(x::ZonedDateTime) = x
Base.:(-)(x::ZonedDateTime, y::ZonedDateTime) = x.utc_datetime - y.utc_datetime

function Base.:(+)(zdt::ZonedDateTime, p::DatePeriod)
    return ZonedDateTime(DateTime(zdt, Local) + p, timezone(zdt))
end
function Base.:(+)(zdt::ZonedDateTime, p::TimePeriod)
    return ZonedDateTime(DateTime(zdt, UTC) + p, timezone(zdt); from_utc=true)
end
function Base.:(-)(zdt::ZonedDateTime, p::DatePeriod)
    return ZonedDateTime(DateTime(zdt, Local) - p, timezone(zdt))
end
function Base.:(-)(zdt::ZonedDateTime, p::TimePeriod)
    return ZonedDateTime(DateTime(zdt, UTC) - p, timezone(zdt); from_utc=true)
end

function broadcasted(::typeof(+), r::StepRange{ZonedDateTime{FixedTimeZone}}, p::DatePeriod)
    start, step, stop = first(r), Base.step(r), last(r)
    return StepRange(start + p, step, stop + p)
end

function broadcasted(::typeof(+), r::StepRange{ZonedDateTime{VariableTimeZone}}, p::DatePeriod)
    start, step, stop = first(r), Base.step(r), last(r)

    # Since the local time + period can result in an invalid local datetime when working with
    # VariableTimeZones we will use `first_valid` and `last_valid` which avoids issues with
    # non-existent and ambiguous dates.

    start = first_valid(DateTime(start, Local) + p, timezone(start), step)
    stop = last_valid(DateTime(stop, Local) + p, timezone(stop), step)
    return StepRange(start, step, stop)
end


broadcasted(::typeof(-), r::StepRange{ZonedDateTime}, p::DatePeriod) = broadcast(+, r, -p)
