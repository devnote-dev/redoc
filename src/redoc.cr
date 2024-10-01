require "json"
require "./redoc/*"

module Redoc
  VERSION = "0.1.0"

  METHOD_PATTERN = /(?:(?:_\w|[a-z])\w*(?:!|\?|=)?|[-+^`~%|]|\*\*?|\/\/?|!(?:=|~)?|=(?:=|==|~)?|<(?:<|=)?|>(?:>|=)?|<=>|&(?:\+|-|\*)?|\[](?:\?|=)?)/
  QUERY_PATTERN  = /^(?:(?<dname>(?:::)?#{METHOD_PATTERN})|(?<tpath>(?:::)?[A-Z]\w*)+(?:(?<tscope>\.|#)(?<tname>#{METHOD_PATTERN}))?)$/

  class Error < Exception
  end

  enum QueryScope
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
  # a nilable string representing the symbol, and the query scope (see `Library#resolve?`).
  # The _pattern_ is expected to be in Crystal path format which is defined as follows:
  #
  # - "::" is used for namespace accessors
  # - "." is used for **class method** accessors
  # - "#" is used for **instance method** accessors
  #
  # The following is in valid format:
  #
  # - `puts`
  # - `::puts`
  # - `String.build`
  # - `::Char::Reader#pos`
  #
  # This also supports operator methods and methods that end in `=`, `!` or `?`:
  #
  # - `!`
  # - `Regex#=~`
  # - `Array#[]?`
  #
  # The following is in invalid format:
  #
  # - `to_s.nil?`
  # - `IO.Memory`
  # - `JSON#Any`
  def self.parse_query?(pattern : String) : {Array(String), String?, QueryScope}?
    return unless match = QUERY_PATTERN.match pattern

    if dname = match["dname"]?
      scope = dname.starts_with?("::") ? QueryScope::TopLevel : QueryScope::All

      return [] of String, dname.lchop("::"), scope
    end

    return unless tpath = match["tpath"]?
    scope = case match["tscope"]?
            when "." then QueryScope::Class
            when "#" then QueryScope::Instance
            else          QueryScope::All
            end

    {tpath.split("::", remove_empty: true), match["tname"]?, scope}
  end

  # Same as `parse_query?` but raises an `Error` if _pattern_ is invalid.
  def self.parse_query(pattern : String) : {Array(String), String?, QueryScope}
    parse_query?(pattern) || raise Error.new "Invalid query pattern format"
  end
end
