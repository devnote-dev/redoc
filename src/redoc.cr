require "json"

require "./redoc/*"

module Redoc
  VERSION       = "0.1.0"
  QUERY_PATTERN = /^(?<ns>(?:::)?[A-Z_]{1,}(?:\w+|::)+)?(?:(?<scp>\.|#|\s+)?(?<sym>[a-zA-Z_]{1,}[\w!?=]|[!?<>^+\-~\/*&%|`]|<<|>>|\/\/|\*\*|===?|\[\]=?))?$/

  def self.parse_query?(pattern : String) : {Array(String), String?, Bool}?
    return unless match = QUERY_PATTERN.match pattern
    namespace = match["ns"]?.try(&.split("::", remove_empty: true)) || [] of String

    {namespace, match["sym"]?, match["scp"]? == "#"}
  end

  def self.parse_query(pattern : String) : {Array(String), String?, Bool}
    parse_query?(pattern) || raise "Invalid query pattern format"
  end
end
