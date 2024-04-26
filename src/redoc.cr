require "json"

require "./redoc/*"

module Redoc
  VERSION       = "0.1.0"
  QUERY_PATTERN = /^(?<ns>(?:(?:::)?[A-Z_]\w*)+)?(?<scp>\.|#)?(?<sym>(?:[a-z_]\w*(?:\?|!|=)?|[~+<|>%&^`*\-\/]|=(?:=|~)|!(?:=|~)?|<<|>>|\*\*|\/\/|===|<=>|\[\]=?))?$/

  class Error < Exception
  end

  enum QueryKind
    Class
    Instance
    All
  end

  # Loads a project from _source_. This should be the generated JSON of a Crystal project
  # which can be obtained from the `crystal docs --json` command.
  def self.load(source : String | IO) : Project
    program = Crystal::Program.from_json source
    Transformer.transform program
  end

  # Parses a query from _pattern_. Returns an array of strings representing the namespace,
  # a nilable string representing the symbol, and the query kind (see `Project#resolve?`).
  # The _pattern_ is expected to be in Crystal path format which is defined as follows:
  #
  # - "::" is used for namespace accessors
  # - "." is used for **class method** accessors
  # - "#" is used for **instance method** accessors
  #
  # The following is in valid format:
  #
  # - `puts`
  # - `String.build`
  # - `Char::Reader#pos`
  #
  # The following is in invalid format:
  #
  # - `::raise`
  # - `IO.Memory`
  # - `JSON#Any`
  #
  # Additional tokens used in identifiers are allowed **only** after symbols or in place
  # of a symbol (for example, `Array#<<` or `Log#level=`).
  def self.parse_query?(pattern : String) : {Array(String), String?, QueryKind}?
    return unless match = QUERY_PATTERN.match pattern

    symbol = match["sym"]?
    namespace = match["ns"]?.try(&.split("::", remove_empty: true)) || [] of String

    case match["scp"]?
    when "." then kind = QueryKind::Class
    when "#" then kind = QueryKind::Instance
    else          kind = QueryKind::All
    end

    {namespace, symbol, kind}
  end

  # Same as `parse_query?` but raises an `Error` if _pattern_ is invalid.
  def self.parse_query(pattern : String) : {Array(String), String?, QueryKind}
    parse_query?(pattern) || raise Error.new "Invalid query pattern format"
  end
end
