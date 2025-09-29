module Inmation

include("core.jl")
include("_InmationRawHistory.jl")

export InmationCredentials, inmation_joinpath
export InmationRawHistory, RawHistoryOptions, writehistory

end
