module Redoc
  module Namespace
    property constants : Array(Const) = [] of Const
    property modules : Array(Module) = [] of Module
    property classes : Array(Class) = [] of Class
    property structs : Array(Struct) = [] of Struct
    property enums : Array(Enum) = [] of Enum
    property aliases : Array(Alias) = [] of Alias
    property annotations : Array(Annotation) = [] of Annotation
  end

  class Project
    include JSON::Serializable
    include Namespace

    getter name : String
    getter description : String
    getter defs : Array(Def) = [] of Def
    getter macros : Array(Macro) = [] of Macro

    # :nodoc:
    def initialize(@name, @description)
    end
  end

  struct Location
    include JSON::Serializable

    getter filename : String
    getter line_number : Int32
    @[JSON::Field(emit_null: true)]
    getter url : String?
  end

  struct TypeRef
    include JSON::Serializable

    enum Kind
      Module
      Class
      Struct
    end

    getter name : String
    getter full_name : String
    getter kind : Kind
  end

  abstract class Type
    include JSON::Serializable

    @[JSON::Field(emit_null: true)]
    property summary : String?
    @[JSON::Field(emit_null: true)]
    property doc : String?
    property? top_level : Bool
  end

  class Const < Type
    property name : String
    property value : String

    def self.new(const : Crystal::ConstDef, top_level : Bool)
      new(
        const.name,
        const.value,
        summary: const.summary,
        doc: const.doc,
        top_level: top_level
      )
    end

    def initialize(@name : String, @value : String, *, @summary : String? = nil,
                   @doc : String? = nil, @top_level : Bool = false)
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
    property locations : Array(Location) = [] of Location

    def initialize(@name : String, @full_name : String, *, @summary : String? = nil,
                   @doc : String?, @top_level : Bool = false)
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
    property locations : Array(Location) = [] of Location

    def initialize(@name : String, @full_name : String, *, @abstract : Bool = false,
                   @summary : String? = nil, @doc : String?, @top_level : Bool = false)
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
    property locations : Array(Location) = [] of Location

    def initialize(@name : String, @full_name : String, *, @abstract : Bool = false,
                   @summary : String? = nil, @doc : String?, @top_level : Bool = false)
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
    property locations : Array(Location) = [] of Location

    def initialize(@name : String, @full_name : String, @constants : Array(Const), *,
                   @type : String? = nil, @summary : String? = nil, @doc : String? = nil,
                   @top_level : Bool = false)
    end
  end

  class Alias < Type
    property name : String
    property full_name : String
    property type : String
    property locations : Array(Location) = [] of Location

    def initialize(@name : String, @full_name : String, @type : String, *,
                   @summary : String? = nil, @doc : String? = nil,
                   @top_level : Bool = false)
    end
  end

  class Annotation < Type
    property name : String
    property full_name : String
    property locations : Array(Location) = [] of Location

    def initialize(@name : String, @full_name : String, *, @summary : String? = nil,
                   @doc : String? = nil, @top_level : Bool = false)
    end
  end

  class Param
    include JSON::Serializable

    property name : String
    @[JSON::Field(emit_null: true)]
    property external_name : String?
    @[JSON::Field(emit_null: true)]
    property type : String?
    @[JSON::Field(emit_null: true)]
    property default_value : String?
    property? block : Bool
    property? splat : Bool
    property? double_splat : Bool

    def self.new(arg : Crystal::MetaArg)
      new(arg.name, arg.external_name, arg.restriction)
    end

    def initialize(@name, @external_name, @type, @default_value = nil)
      @block = @splat = @double_splat = false
    end
  end

  class Def < Type
    property name : String
    property params : Array(Param)
    @[JSON::Field(emit_null: true)]
    property return_type : String?
    property? abstract : Bool
    property? generic : Bool
    property location : Location?

    def self.new(method : Crystal::Def, top_level : Bool)
      params = method.args.try(&.map { |a| Param.new a }) || [] of Param

      new(
        method.name,
        params: params,
        return_type: method.def.return_type,
        abstract: method.abstract?,
        generic: false,
        location: method.location,
        summary: method.summary,
        doc: method.doc,
        top_level: top_level,
      )
    end

    def initialize(@name : String, *, @params : Array(Param) = [] of Param,
                   @return_type : String? = nil, @abstract : Bool = false,
                   @generic : Bool = false, @location : Location? = nil,
                   @summary : String? = nil, @doc : String? = nil,
                   @top_level : Bool = false)
    end
  end

  class Macro < Type
    property name : String
    property params : Array(Param)
    @[JSON::Field(emit_null: true)]
    property location : Location?

    def self.new(method : Crystal::Def, top_level : Bool)
      params = method.args.try(&.map { |a| Param.new a }) || [] of Param

      new(
        method.name,
        params: params,
        location: method.location,
        summary: method.summary,
        doc: method.doc,
        top_level: top_level,
      )
    end

    def initialize(@name : String, *, @params : Array(Param) = [] of Param,
                   @location : Location? = nil, @summary : String? = nil,
                   @doc : String? = nil, @top_level : Bool = false)
    end
  end
end
