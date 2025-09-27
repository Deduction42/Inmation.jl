
#========================================================================================================
Inmation response structures and conversions
========================================================================================================#
@kwdef struct InmationRawHistory{T}
    p :: String
    t :: Vector{Float64}
    v :: Vector{T}
    q :: Vector{Int8}
end

struct RawHistoryResponse{T}
    data :: @NamedTuple{
        historical_data::@NamedTuple{
            query_data::Vector{
                @NamedTuple{
                    start_time::String,
                    end_time::String,
                    items::Vector{InmationRawHistory{T}}
                }
            }
        }
    }
end

function RawHistoryResponse{T}(credentials::InmationCredentials, tagpath::String, timerange::Pair{DateTime, DateTime}) where T
    return RawHistoryResponse{T}(rawhistory(credentials, tagpath, timerange))
end
RawHistoryResponse{T}(resp::HTTP.Messages.Response) where T = JSON3.read(resp.body, RawHistoryResponse{T}, parsequoted=true)

function InmationRawHistory{T}(credentials::InmationCredentials, tagpath::String, timerange::Pair{DateTime, DateTime}) where T
    return InmationRawHistory(RawHistoryResponse{T}(credentials, tagpath, timerange))
end
InmationRawHistory(obj::RawHistoryResponse) = obj.data.historical_data.query_data[begin].items[begin]
InmationRawHistory{T}(obj::RawHistoryResponse) where T = InmationRawHistory{T}(InmationRawHistory(obj))

#========================================================================================================
Timeseries data compatability layer (Julia uses s since epoch, Inmation uses ms)
========================================================================================================#
function TimeRecords.TimeSeries(data::InmationRawHistory)
    return TimeSeries(0.001.*data.t, data.v)
end 

function InmationRawHistory(tag::String, data::TimeSeries)
    return InmationRawHistory(p=tag, t=timestamps(data).*1000, v=values(data), q=zeros(Int8, length(timestamps(data))))
end

#========================================================================================================
Inmation API functions
========================================================================================================#
function rawhistory(credentials::InmationCredentials, tagpath::String, timerange::Pair{DateTime, DateTime})
    headers = [
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "username" => credentials.username,
        "password" => credentials.password,
    ]
    
    query   = _rawhistory_query(tagpath, timerange)
    histurl = credentials.url*"/api/v2/readrawhistoricaldata"
    request = HTTP.post(histurl, headers, query)
    @info "Queried data (code = $(request.status)) over{$(string(timerange))} for {tag = $(tagpath)}"

    return request
end

function rawhistory2file(filename::String, credentials::InmationCredentials, tagpath::String, timerange::Pair{DateTime, DateTime})
    request = rawhistory(credentials, tagpath, timerange)
    open(filename, "w") do fh
        JSON3.pretty(fh, String(request.body))
    end
    return nothing
end

function writehistory(credentials::InmationCredentials, data::InmationRawHistory{T}) where T
    headers = [
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "username" => credentials.username,
        "password" => credentials.password,
    ]

    timerange = Pair(extrema(data.t)...)
    payload   = _writehistory_payload(data)
    histurl   = credentials.url*"/api/v2/write"
    request   = HTTP.post(histurl, headers, payload)
    @info "Wrote data (code = $(request.status)) over{$(timerange)} for {tag = $(data.p)}"

    return nothing
end

#========================================================================================================
Helper functions
========================================================================================================#
function _rawhistory_query(tagpath::String, timerange::Pair{DateTime, DateTime})
    (start, stop) = extrema(timerange)

    query = """
    {
      "items": [
        {
          "p": "$(tagpath)"
        }
      ],
      "start_time": "$(start).000Z",
      "end_time": "$(stop).000Z",
      "fields": [
        "v",
        "q",
        "t"
      ],
      "query_count_limit": 3000000,
      "bounds": true
    }
    """

    return query
end


function _writehistory_payload(data::InmationRawHistory)
    series = [(p=data.p, v=v, q=0, t=t) for (t,v) in zip(data.t, data.v)]
    return JSON3.write((items=series,))
end