primitive type VariableTimeZoneF <: TimeZone 16 end

struct TransitionSet
    utc_datetimes::Vector{DateTime}
    utc_offsets::Vector{Second}
    dst_offsets::Vector{Second}
    names::Vector{String}
end
