using JSON3
using HTTP
using Dates
using TimeRecords

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


