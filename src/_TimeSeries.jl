using TimeRecords

#========================================================================================================
Timeseries data compatability layer (Julia uses s since epoch, Inmation uses ms)
========================================================================================================#
TimeRecords.TimeRecord(ir::InmationRecord) = TimeRecord(0.001*ir.t, ir.v)

function TimeRecords.TimeSeries(data::InmationRawHistory)
    return TimeSeries(TimeRecord.(data))
end 


InmationRecord(tag::String, tr::TimeRecord) = InmationRecord(p=tag, t=round(Int128, timestamp(tr)*1000), v=value(tr), q=0)

function InmationRawHistory(tag::String, data::AbstractTimeSeries)
    return InmationRawHistory(p=tag, t=round.(Int128, timestamps(data).*1000), v=values(data), q=zeros(Int64, length(timestamps(data))))
end
