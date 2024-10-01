require "json"

require "./redoc/*"

module Redoc
  VERSION = "0.1.0"

  METHOD_PATTERN = /(?:(?:_\w|[a-z])\w*(?:!|\?|=)?|[-+^`~%|]|\*\*?|\/\/?|!(?:=|~)?|=(?:=|==|~)?|<(?:<|=)?|>(?:>|=)?|<=>|&(?:\+|-|\*)?|\[](?:\?|=)?)/
  QUERY_PATTERN  = /^(?:(?<dname>(?:::)?#{METHOD_PATTERN})|(?<tpath>(?:::)?[A-Z]\w*)+(?:(?<tscope>\.|#)(?<tname>#{METHOD_PATTERN}))?)$/

  class Error < Exception
  end

  enum QueryKind
    All
    TopLevel
    Class
    Instance
  end

  # Loads a library from _source_. This should be the generated JSON of a Crystal library
  # which can be obtained from the `crystal docs --json` command.
  def self.load(source : String | IO) : Library
    program = Crystal::Program.from_json source
    Transformer.transform program
  end

  # Parses a query from _pattern_. Returns an array of strings representing the namespace,
  # a nilable string representing the symbol, and the query kind (see `Library#resolve?`).
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

    if dname = match["dname"]?
      return [] of String, dname, (dname.starts_with?("::") ? QueryKind::TopLevel : QueryKind::All)
    end

    return unless tpath = match["tpath"]?
    kind = case match["scope"]?
           when "." then QueryKind::Class
           when "#" then QueryKind::Instance
           else          QueryKind::All
           end

    {tpath.split("::", remove_empty: true), match["tname"]?, kind}
  end

  # Same as `parse_query?` but raises an `Error` if _pattern_ is invalid.
  def self.parse_query(pattern : String) : {Array(String), String?, QueryKind}
    parse_query?(pattern) || raise Error.new "Invalid query pattern format"
  end
end
