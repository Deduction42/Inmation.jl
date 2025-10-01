using JSON3
using HTTP
using Dates

#========================================================================================================
Credentials setup
========================================================================================================#
@kwdef struct InmationCredentials
    url :: String
    username :: String
    password :: String
end

InmationCredentials(url::String, obj::AbstractDict{Symbol,<:Any}) = InmationCredentials(url, obj[:username], obj[:password])
inmation_joinpath(x...) = join(rstrip.(x,'/'), "/")

@kwdef struct InmationRecord{T}
    p :: String
    t :: Int128
    v :: T
    q :: Int64
end

#Divides history into chunks (by default, of 1000), and sends them individually
function writehistory(credentials::InmationCredentials, data::AbstractVector{InmationRecord{T}}; chunksize=1000, verbose=true) where T
    if chunksize > 1000
        @warn "Chunk size over 1000 not allowed, reducing chunk size to 1000"
        knots = 1:1000:length(data)
    else
        knots = 1:floor(Int64, chunksize):length(data)
    end

    #Write all chunks before the end
    for ii in firstindex(knots):(lastindex(knots)-1)
        chunk_ind = knots[ii]:(knots[ii+1]-1)
        _writechunk(credentials, data[chunk_ind], verbose=verbose)
    end

    #Write the last chunk
    _writechunk(credentials, data[knots[end]:end], verbose=verbose)

    return nothing
end

#Writes a chunk directly without breaking to smaller pieces
function _writechunk(credentials::InmationCredentials, data::AbstractVector{<:InmationRecord}; verbose=true)
    headers = [
        "Content-Type" => "application/json",
        "Accept" => "application/json",
        "username" => credentials.username,
        "password" => credentials.password,
    ]

    if length(data) > 1000
        error("Not allowed to write history with more than 1000 elements (recieved $(length(data)))")
    end

    tagname   = first(data).p
    daterange = Pair( string.(unix2datetime.(extrema(x-> x.t, data)./1000))...)
    payload   = json_payload(data)
    histurl   = credentials.url*"/api/v2/write"
    request   = HTTP.post(histurl, headers, payload)

    if request.status != 200
        @warn "Failed to write data (code=$(request.status)) over {$(daterange)} for {tag = $(tagname)}"
    elseif verbose 
        @info "Wrote data (code = $(request.status)) over {$(daterange)} for {tag = $(tagname)}"
    end
    return nothing
end

function json_payload(v::AbstractVector{<:InmationRecord})
    series_obj = (items=v[:],)
    return JSON3.write(series_obj)
end