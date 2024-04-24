module Redoc
  # :nodoc:
  module Crystal
    class Program
      include JSON::Serializable

      getter repository_name : String
      getter body : String
      getter program : Type
    end

    enum Kind
      Module
      Class
      Struct
      Enum
      Alias
      Annotation
    end

    struct ConstDef
      include JSON::Serializable

      getter name : String
      getter value : String
      getter doc : String?
      getter summary : String?
    end

    struct Def
      include JSON::Serializable

      getter name : String
      getter doc : String?
      getter summary : String?
      getter? abstract : Bool
      getter args : Array(MetaArg)?
      getter args_string : String?
      getter location : Location?
      getter def : MetaDef
    end

    struct MetaArg
      include JSON::Serializable

      getter name : String
      getter external_name : String
      getter restriction : String
    end

    struct MetaDef
      include JSON::Serializable

      getter name : String
      getter args : Array(MetaArg)?
      getter return_type : String?
      getter body : String
    end

    class Type
      include JSON::Serializable

      getter name : String
      getter full_name : String
      getter? abstract : Bool
      getter superclass : TypeRef?
      getter kind : Kind
      getter aliased : String?
      getter ancestors : Array(TypeRef)?
      getter locations : Array(Location)
      getter repository_name : String
      getter? program : Bool
      getter? enum : Bool
      getter? alias : Bool
      getter? const : Bool
      getter doc : String?
      getter summary : String?
      getter constants : Array(ConstDef)?
      getter included_modules : Array(TypeRef)?
      getter extended_modules : Array(TypeRef)?
      getter constructors : Array(Def)?
      getter class_methods : Array(Def)?
      getter instance_methods : Array(Def)?
      getter macros : Array(Def)?
      getter types : Array(Type)?
    end
  end
end
