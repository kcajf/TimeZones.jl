struct FixedTimeZoneF <: TimeZone
    local_minus_utc::Int32
    function FixedTimeZoneF(secs::Int)
        if (-86_400 < secs) && (secs < 86_400)
           new(secs) 
        else
            error("Invalid offset")
        end
    end 
end

FixedTimeZoneF(s::Second) = FixedTimeZoneF(s.value)

function name(tz::FixedTimeZoneF)
    offset = tz.local_minus_utc

    # TODO: could use offset_string in utcoffsets.jl with some adaptation
    if offset < 0
        sig = '-'
        offset = -offset
    else
        sig = '+'
    end

    hour, rem = divrem(offset, 3600)
    minute, second = divrem(rem, 60)
    
    if hour == 0 && minute == 0 && second == 0
        name = "UTC"
    elseif second == 0
        name = @sprintf("UTC%c%02d:%02d", sig, hour, minute)
    else
        name = @sprintf("UTC%c%02d:%02d:%02d", sig, hour, minute, second)
    end
    return name
end