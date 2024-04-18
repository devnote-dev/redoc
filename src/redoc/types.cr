module Redoc
  class Program
    getter name : String
    getter description : String

    getter constants : Array(Const) = [] of Const
    getter modules : Array(Module) = [] of Module
    getter classes : Array(Class) = [] of Class
    getter structs : Array(Struct) = [] of Struct
    getter enums : Array(Enum) = [] of Enum
    getter aliases : Array(Alias) = [] of Alias
    getter annotations : Array(Annotation) = [] of Annotation
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
    getter url : String?
  end

  abstract class Type
    include JSON::Serializable

    getter name : String
    getter full_name : String
    getter summary : String?
    getter doc : String?
    getter? top_level : Bool
  end

  abstract class Namespace < Type
    getter constants : Array(Const)
    getter modules : Array(Module)
    getter classes : Array(Class)
    getter structs : Array(Struct)
    getter enums : Array(Enum)
    getter aliases : Array(Alias)
    getter annotations : Array(Annotation)
    getter class_methods : Array(Def)
    getter instance_methods : Array(Def)
    getter macros : Array(Macro)
  end

  class Const < Type
    getter value : String?
    getter location : Location

    def initialize(@name, @full_name, @summary, @doc, @top_level,
                   @value, @location)
    end
  end

  class Module < Namespace
    getter includes : Array(Module)
    getter extends : Array(Module)
    getter? private : Bool
    getter locations : Array(Location)
  end

  class Class < Namespace
    property generics : Set(String)
    property parent : Class?
    getter ancestors : Array(Namespace) = [] of Namespace
    getter includes : Array(Module) = [] of Module
    getter extends : Array(Module) = [] of Module
    getter constructors : Array(Def) = [] of Def
    property? private : Bool = false
    property? abstract : Bool = false
    property locations : Array(Location) = [] of Location

    def initialize(@name, @full_name, @summary, @doc, @top_level)
      if @full_name.includes? '('
        @generics = @full_name
          .split('(')[1]
          .gsub(' ', "")[..-2]
          .split(',')
          .to_set
      end
    end
  end

  class Struct < Namespace
    getter generics : Set(String)
    getter parent : Struct?
    getter ancestors : Array(Namespace)
    getter includes : Array(Module)
    getter extends : Array(Module)
    getter constructors : Array(Def)
    getter? private : Bool
    getter? abstract : Bool
    getter locations : Array(Location)
  end

  class Enum < Type
    getter type : String?
    getter members : Hash(String, String?)
    getter class_methods : Array(Def)
    getter instance_methods : Array(Def)
    getter constructors : Array(Def)
    getter? private : Bool
    getter location : Location
  end

  class Alias < Type
    getter type : String
    getter? private : Bool
    getter location : Location
  end

  class Annotation < Type
    getter locations : Array(Location)
  end

  struct Param
    include JSON::Serializable

    getter name : String
    getter external_name : String?
    getter type : String?
    getter default_value : String?
    getter? block : Bool
    getter? splat : Bool
    getter? double_splat : Bool
  end

  class Def < Type
    getter params : Array(Param)
    getter return_type : String?
    getter? private : Bool
    getter? protected : Bool
    getter? abstract : Bool
    getter? generic : Bool
    getter location : Location
  end

  class Macro < Type
    getter params : Array(Param)
    getter? private : Bool
    getter location : Location
  end
end
