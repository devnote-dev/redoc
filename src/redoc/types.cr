module Redoc
  # Represents a namespace type in Crystal. This can be a module, class or struct.
  module Namespace
    property constants : Array(Const) = [] of Const
    property modules : Array(Module) = [] of Module
    property classes : Array(Class) = [] of Class
    property structs : Array(Struct) = [] of Struct
    property enums : Array(Enum) = [] of Enum
    property aliases : Array(Alias) = [] of Alias
    property annotations : Array(Annotation) = [] of Annotation
  end

  # Represents a library (known as _Program_ in the Crystal compiler). This contains the
  # name and description of the library, top-level definitions (constants, macros and
  # methods), and encapsulates all types defined and documented in the library.
  class Library
    include JSON::Serializable
    include Namespace

    # The name of the library.
    getter name : String

    # The description of the library.
    getter description : String

    # An array of top-level methods.
    getter defs : Array(Def) = [] of Def

    # An array of top-level macros.
    getter macros : Array(Macro) = [] of Macro

    # :nodoc:
    def initialize(@name, @description)
    end

    # Resolves a query _pattern_ to a type in the library. This uses the Crystal path
    # format to denote constants from symbols/identifiers. Raises if the pattern is
    # invalid or no type or symbol is found.
    #
    # ```
    # require "redoc"
    #
    # library = File.open "./source.json" do |file|
    #   Redoc.load file
    # end
    #
    # library.resolve "VERSION" # => #<Redoc::Const:...>
    # ```
    def resolve(pattern : String) : Type
      resolve?(pattern) || raise Error.new "Type or symbol not found"
    end

    # Same as `resolve` but returns `nil` if no type or symbol is found.
    #
    # WARNING: this method can stil raise if the _pattern_ is not in valid Crystal path
    # format.
    #
    # ```
    # require "redoc"
    #
    # library = File.open "./source.json" do |file|
    #   Redoc.load file
    # end
    #
    # library.resolve? "UNKNOWN"   # => nil
    # library.resolve? "::unknown" # => raises Exception
    # ```
    def resolve?(pattern : String) : Type?
      resolve? *Redoc.parse_query pattern
    end

    # Same as `resolve?` using unparsed inputs. The _namespace_ is an array of strings
    # representing the namespace path. The `symbol` is an identifier or operator and
    # _kind_ is an enum value representing how _symbol_ should be looked up. Returns
    # `nil` if no type or symbol is found in the given _namespace_.
    #
    # WARNING: in most if not all cases you should use `resolve?` to ensure that input
    # parameters are correctly parsed. This method does _not_ do additional parsing or
    # validation of input parameters.
    #
    # When _kind_ is set to `QueryKind::Class` only class methods (including
    # constructors) and macros will be looked up, when set to `QueryKind::Instance` only
    # instance methods are looked up, and when set to `QueryKind::All` both are checked.
    #
    # ```
    # require "redoc"
    #
    # library = File.open "./source.json" do |file|
    #   Redoc.load file
    # end
    #
    # library.resolve?(["Regex"], "=~", :class)    # => nil
    # library.resolve?(["Regex"], "=~", :instance) # => #<Redoc::Def:...>
    # ```
    def resolve?(namespace : Array(String), symbol : String?, kind : QueryKind) : Type?
      if namespace.empty?
        return @defs.find { |d| d.name == symbol } || @macros.find { |m| m.name == symbol }
      end

      unless symbol && namespace.size == 1
        if const = @constants.find { |c| c.name == namespace[0] }
          return const
        end
      end

      return unless type = recurse self, namespace
      return type unless symbol

      if kind.class? || kind.all?
        if type.responds_to?(:constructors)
          if method = type.constructors.find { |c| c.name == symbol }
            return method
          end
        end

        if type.responds_to?(:class_methods)
          if method = type.class_methods.find { |c| c.name == symbol }
            return method
          end
        end

        if type.responds_to?(:macros)
          if method = type.macros.find { |m| m.name == symbol }
            return method
          end
        end
      end

      if kind.instance? || kind.all?
        if type.responds_to?(:instance_methods)
          return type.instance_methods.find { |c| c.name == symbol }
        end
      end
    end

    private def recurse(namespace : Namespace, names : Array(String)) : Type?
      if names.size == 1
        if const = namespace.constants.find { |c| c.name == names[0] }
          return const
        end
      end

      {% for type in %w[modules classes structs] %}
        if type = namespace.{{type.id}}.find { |t| t.name == names[0] }
          return type if names.size == 1
          names.shift
          return recurse type, names
        end
      {% end %}

      {% for type in %w[enums aliases annotations] %}
        if type = namespace.{{type.id}}.find { |t| t.name == names[0] }
          return if names.size > 1
          return type
        end
      {% end %}
    end

    def resolve_all(pattern : String) : Array(Type)
      namespace, symbol, kind = Redoc.parse_query pattern
      raise Error.new "Missing symbol pattern in query" unless symbol

      resolve_all namespace, symbol, kind
    end

    def resolve_all(namespace : Array(String), symbol : String, kind : QueryKind) : Array(Type)
      unless type = resolve?(namespace, nil, kind)
        return ([] of Type)
          .concat(@defs.select { |d| d.name == symbol })
          .concat(@macros.select { |m| m.name == symbol })
      end

      found = [] of Type

      if kind.all? || kind.class?
        if type.responds_to?(:constructors)
          found.concat type.constructors.select { |m| m.name == symbol }
        end

        if type.responds_to?(:class_methods)
          found.concat type.class_methods.select { |m| m.name == symbol }
        end

        if type.responds_to?(:macros)
          found.concat type.macros.select { |m| m.name == symbol }
        end
      end

      if kind.all? || kind.instance?
        if type.responds_to?(:instance_methods)
          found.concat type.instance_methods.select { |m| m.name == symbol }
        end
      end

      found
    end
  end

  # Represents a type's location in a library.
  struct Location
    include JSON::Serializable

    # The filename of the type.
    getter filename : String

    # The line number of the type's definition.
    getter line_number : Int32

    # A generated URL to the type (likely a repository).
    @[JSON::Field(emit_null: true)]
    getter url : String?
  end

  # Represents a type reference in a namespaced type.
  class TypeRef
    include JSON::Serializable

    enum Kind
      Module
      Class
      Struct
      Enum
    end

    # The name of the referenced type.
    getter name : String

    # The full name (or Fully-Qualified Name) of the referenced type.
    getter full_name : String

    # The kind of the referenced type.
    getter kind : Kind

    # :nodoc:
    def initialize(@name, @full_name, @kind)
    end
  end

  # Represents all types in a Crystal library. This is mainly used internally in Redoc
  # for transformation and type resolution.
  abstract class Type
    include JSON::Serializable

    # A summary of the type.
    @[JSON::Field(emit_null: true)]
    property summary : String?

    # The documentation of the type.
    @[JSON::Field(emit_null: true)]
    property doc : String?

    # Whether the type is defined in the top-level namespace.
    property? top_level : Bool
  end

  class Const < Type
    property name : String
    property value : String
    property parent : TypeRef?

    def self.new(const : Crystal::ConstDef, ref : TypeRef?)
      new(
        const.name,
        const.value,
        parent: ref,
        summary: const.summary,
        doc: const.doc,
        top_level: ref.nil?
      )
    end

    def initialize(@name : String, @value : String, *, @parent : TypeRef? = nil,
                   @summary : String? = nil, @doc : String? = nil,
                   @top_level : Bool = false)
    end
  end

  class Module < Type
    include Namespace

    property name : String
    property full_name : String
    property includes : Array(TypeRef) = [] of TypeRef
    property including_types : Array(TypeRef) = [] of TypeRef
    property extends : Array(TypeRef) = [] of TypeRef
    property class_methods : Array(Def) = [] of Def
    property instance_methods : Array(Def) = [] of Def
    property macros : Array(Macro) = [] of Macro
    property locations : Array(Location)

    def initialize(@name : String, @full_name : String, *,
                   @locations : Array(Location) = [] of Location,
                   @summary : String? = nil, @doc : String?, @top_level : Bool = false)
    end

    def extends_self? : Bool
      @extends.any? { |m| m.full_name == @full_name }
    end
  end

  class Class < Type
    include Namespace

    property name : String
    property full_name : String
    property generics : Set(String)
    @[JSON::Field(emit_null: true)]
    property parent : TypeRef?
    property ancestors : Array(TypeRef) = [] of TypeRef
    property includes : Array(TypeRef) = [] of TypeRef
    property extends : Array(TypeRef) = [] of TypeRef
    property class_methods : Array(Def) = [] of Def
    property constructors : Array(Def) = [] of Def
    property instance_methods : Array(Def) = [] of Def
    property macros : Array(Macro) = [] of Macro
    property? abstract : Bool = false
    property locations : Array(Location)

    def initialize(@name : String, @full_name : String, *, @abstract : Bool = false,
                   @locations : Array(Location) = [] of Location, @summary : String? = nil,
                   @doc : String?, @top_level : Bool = false)
      if @full_name.includes? '('
        @generics = @full_name
          .split('(')[1]
          .gsub(' ', "")[..-2]
          .split(',')
          .to_set
      else
        @generics = Set(String).new
      end
    end
  end

  class Struct < Type
    include Namespace

    property name : String
    property full_name : String
    property generics : Set(String)
    @[JSON::Field(emit_null: true)]
    property parent : TypeRef?
    property ancestors : Array(TypeRef) = [] of TypeRef
    property includes : Array(TypeRef) = [] of TypeRef
    property extends : Array(TypeRef) = [] of TypeRef
    property class_methods : Array(Def) = [] of Def
    property constructors : Array(Def) = [] of Def
    property instance_methods : Array(Def) = [] of Def
    property macros : Array(Macro) = [] of Macro
    property? abstract : Bool
    property locations : Array(Location)

    def initialize(@name : String, @full_name : String, *, @abstract : Bool = false,
                   @locations : Array(Location) = [] of Location, @summary : String? = nil,
                   @doc : String?, @top_level : Bool = false)
      if @full_name.includes? '('
        @generics = @full_name
          .split('(')[1]
          .gsub(' ', "")[..-2]
          .split(',')
          .to_set
      else
        @generics = Set(String).new
      end
    end
  end

  class Enum < Type
    property name : String
    property full_name : String
    @[JSON::Field(emit_null: true)]
    property type : String?
    property constants : Array(Const)
    property ancestors : Array(TypeRef) = [] of TypeRef
    property class_methods : Array(Def) = [] of Def
    property constructors : Array(Def) = [] of Def
    property instance_methods : Array(Def) = [] of Def
    property locations : Array(Location)

    def initialize(@name : String, @full_name : String, @constants : Array(Const), *,
                   @type : String? = nil, @locations : Array(Location) = [] of Location,
                   @summary : String? = nil, @doc : String? = nil, @top_level : Bool = false)
    end
  end

  class Alias < Type
    property name : String
    property full_name : String
    property type : String
    property locations : Array(Location)

    def initialize(@name : String, @full_name : String, @type : String, *,
                   @locations : Array(Location) = [] of Location, @summary : String? = nil,
                   @doc : String? = nil, @top_level : Bool = false)
    end
  end

  class Annotation < Type
    property name : String
    property full_name : String
    property locations : Array(Location)

    def initialize(@name : String, @full_name : String, *,
                   @locations : Array(Location) = [] of Location, @summary : String? = nil,
                   @doc : String? = nil, @top_level : Bool = false)
    end
  end

  class Parameter
    include JSON::Serializable

    property name : String
    # @[JSON::Field(emit_null: true)]
    # property external_name : String?
    # property internal_name : String?
    @[JSON::Field(emit_null: true)]
    property type : String?
    @[JSON::Field(emit_null: true)]
    property default_value : String?
    property? block : Bool
    property? splat : Bool
    property? double_splat : Bool

    def self.new(arg : Crystal::MetaArg)
      new(arg.external_name, arg.restriction.presence, arg.default_value)
    end

    def initialize(@name, @type, @default_value)
      @block = @splat = @double_splat = false
    end
  end

  class Def < Type
    property name : String
    property params : Array(Parameter)
    @[JSON::Field(emit_null: true)]
    property return_type : String?
    property free_vars : Set(String)
    property? abstract : Bool
    property? yields : Bool
    property parent : TypeRef?
    property body : String?
    property location : Location?

    def self.new(method : Crystal::Def, ref : TypeRef?)
      params = method.args.try(&.map { |a| Parameter.new a }) || [] of Parameter

      if index = method.def.splat_index
        params[index].splat = true
      end

      if arg = method.def.double_splat
        params << Parameter.new(arg).tap &.double_splat = true
      end

      if arg = method.def.block_arg
        params << Parameter.new(arg).tap &.block = true
      end

      if str = method.args_string
        if str.includes?("forall")
          free_vars = str
            .split("forall")[1]
            .gsub(' ', "")
            .split(',')
            .to_set
        else
          free_vars = Set(String).new
        end
      else
        free_vars = Set(String).new
      end

      new(
        method.name,
        params: params,
        return_type: method.def.return_type,
        free_vars: free_vars,
        abstract: method.abstract?,
        yields: !!method.def.yields,
        parent: ref,
        body: method.def.body.presence,
        location: method.location,
        summary: method.summary,
        doc: method.doc,
        top_level: ref.nil?,
      )
    end

    def initialize(@name : String, *, @params : Array(Parameter) = [] of Parameter,
                   @return_type : String? = nil, @free_vars : Set(String) = Set(String).new,
                   @abstract : Bool = false, @yields : Bool = false, @parent : TypeRef? = nil,
                   @body : String? = nil, @location : Location? = nil, @summary : String? = nil,
                   @doc : String? = nil, @top_level : Bool = false)
    end

    def generic? : Bool
      !@free_vars.empty?
    end
  end

  class Macro < Type
    property name : String
    property params : Array(Parameter)
    property parent : TypeRef?
    property body : String?
    @[JSON::Field(emit_null: true)]
    property location : Location?

    def self.new(method : Crystal::Def, ref : TypeRef?)
      params = method.args.try(&.map { |a| Parameter.new a }) || [] of Parameter

      if index = method.def.splat_index
        params[index].splat = true
      end

      if arg = method.def.double_splat
        params << Parameter.new(arg).tap &.double_splat = true
      end

      if arg = method.def.block_arg
        params << Parameter.new(arg).tap &.block = true
      end

      new(
        method.name,
        params: params,
        parent: ref,
        body: method.def.body.presence,
        location: method.location,
        summary: method.summary,
        doc: method.doc,
        top_level: ref.nil?,
      )
    end

    def initialize(@name : String, *, @params : Array(Parameter) = [] of Parameter,
                   @parent : TypeRef? = nil, @body : String? = nil,
                   @location : Location? = nil, @summary : String? = nil,
                   @doc : String? = nil, @top_level : Bool = false)
    end
  end
end
