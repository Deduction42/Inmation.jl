
#========================================================================================================
Inmation response structures and conversions
========================================================================================================#
@kwdef struct InmationRawHistory{T} <: AbstractVector{InmationRecord{T}}
    p :: String
    t :: Vector{Int128}
    v :: Vector{T}
    q :: Vector{Int64}
end

Base.firstindex(x::InmationRawHistory) = firstindex(x.t)
Base.lastindex(x::InmationRawHistory) = lastindex(x.t)
Base.getindex(x::InmationRawHistory, ind::Integer) = InmationRecord(x.p, x.t[ind], x.v[ind], x.q[ind])
Base.getindex(x::InmationRawHistory, inds::AbstractVector{<:Integer}) = map(Base.Fix1(getindex, x), inds)
Base.getindex(x::InmationRawHistory, ind::Colon) = getindex(x, firstindex(x):lastindex(x))
Base.length(x::InmationRawHistory) = length(x.t)

const BOUND_MODE = (inner=0, outer=1, before=2, after=3)

@kwdef mutable struct RawHistoryOptions
    tagpath  :: String 
    interval :: Pair{DateTime, DateTime}
    boundmode :: Int = BOUND_MODE.inner
end 

struct RawHistoryResponse{T}
    data :: @NamedTuple{
        historical_data :: @NamedTuple{
            query_data :: Vector{
                @NamedTuple{
                    start_time :: String,
                    end_time :: String,
                    items :: Vector{InmationRawHistory{T}}
                }
            }
        }
    }
end

function RawHistoryResponse{T}(credentials::InmationCredentials, options::RawHistoryOptions) where T
    return RawHistoryResponse{T}(rawhistory(credentials, options))
end
RawHistoryResponse{T}(resp::HTTP.Messages.Response) where T = JSON3.read(resp.body, RawHistoryResponse{T}, parsequoted=true)

function InmationRawHistory{T}(credentials::InmationCredentials, options::RawHistoryOptions) where T
    return InmationRawHistory(RawHistoryResponse{T}(credentials, options))
end
InmationRawHistory(obj::RawHistoryResponse) = obj.data.historical_data.query_data[begin].items[begin]
InmationRawHistory{T}(obj::RawHistoryResponse) where T = InmationRawHistory{T}(InmationRawHistory(obj))

#========================================================================================================
Timeseries data compatability layer (Julia uses s since epoch, Inmation uses ms)
========================================================================================================#
function TimeRecords.TimeSeries(data::InmationRawHistory)
    return TimeSeries(0.001.*data.t, data.v)
end 

function InmationRawHistory(tag::String, data::AbstractTimeSeries)
    return InmationRawHistory(p=tag, t=round.(Int128, timestamps(data).*1000), v=values(data), q=zeros(Int64, length(timestamps(data))))
end

#========================================================================================================
Inmation API functions
========================================================================================================#
function rawhistory(credentials::InmationCredentials, options::RawHistoryOptions)
    headers = [
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "username" => credentials.username,
        "password" => credentials.password,
    ]
    
    query   = _rawhistory_query(options)
    histurl = credentials.url*"/api/v2/readrawhistoricaldata"
    request = HTTP.post(histurl, headers, query)
    @info "Queried data (code = $(request.status)) over{$(string(options.interval))} for {tag = $(options.tagpath)}"

    return request
end

function rawhistory2file(filename::String, credentials::InmationCredentials, options::RawHistoryOptions)
    request = rawhistory(credentials, options)
    open(filename, "w") do fh
        JSON3.pretty(fh, String(request.body))
    end
    return nothing
end



#========================================================================================================
Helper functions
========================================================================================================#
function _rawhistory_query(options::RawHistoryOptions)
    (start, stop) = extrema(options.interval)

    query = """
    {
      "items": [
        {
          "p": "$(options.tagpath)"
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
      "bounds": $(options.boundmode)
    }
    """

    return query
end
