require "json"

require "./redoc/*"

module Redoc
  VERSION       = "0.1.0"
  QUERY_PATTERN = /^(?<ns>(?:::)?[A-Z_]{1,}(?:\w+|::)+)?(?:(?<scp>\.|#|\s+)?(?<sym>[a-zA-Z_]{1,}[\w!?=]|[!?<>^+\-~\/*&%|`]|(?:!|=)(?:=|~)|===|<=>|<<|>>|\/\/|\*\*|\[\]=?))?$/

  enum QueryKind
    Class
    Instance
    All
  end

  def self.load(source : String | IO) : Project
    program = Crystal::Program.from_json source
    Transformer.transform program
  end

  def self.parse_query?(pattern : String) : {Array(String), String?, QueryKind}?
    return unless match = QUERY_PATTERN.match pattern

    symbol = match["sym"]?
    namespace = match["ns"]?.try(&.split("::", remove_empty: true)) || [] of String

    if namespace.empty? || symbol && /#|[^\w]+/.matches? symbol
      kind = QueryKind::All
    elsif match["scp"]? == "#"
      kind = QueryKind::Instance
    else
      kind = QueryKind::Class
    end

    {namespace, symbol, kind}
  end

  def self.parse_query(pattern : String) : {Array(String), String?, QueryKind}
    parse_query?(pattern) || raise "Invalid query pattern format"
  end
end
