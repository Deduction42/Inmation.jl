using TimeRecords

#========================================================================================================
Timeseries data compatability layer (Julia uses s since epoch, Inmation uses ms)
========================================================================================================#
TimeRecords.TimeRecord(ir::InmationRecord) = TimeRecord(0.001*ir.t, ir.v)

function TimeRecords.TimeSeries(f::Function, data::InmationRawHistory{T}) where T
    vr = [f(TimeRecord(data[ii])) for ii in firstindex(data):lastindex(data)]
    return TimeSeries(vr)
end 


function TimeRecords.TimeSeries(data::InmationRawHistory{T}) where T
    vr = TimeRecord{T}[TimeRecord(data[ii]) for ii in firstindex(data):lastindex(data)]
    return TimeSeries{T}(vr)
end 

InmationRecord(tag::String, tr::TimeRecord) = InmationRecord(p=tag, t=round(Int128, timestamp(tr)*1000), v=value(tr), q=0)

function InmationRawHistory(tag::String, data::AbstractTimeSeries{T}) where T
    return InmationRawHistory{T}(p=tag, t=round.(Int128, timestamps(data).*1000), v=values(data), q=zeros(Int64, length(timestamps(data))))
end
