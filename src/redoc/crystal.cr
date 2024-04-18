module Redoc
  private module Crystal
    class Project
      include JSON::Serializable

      getter repository_name : String
      getter body : String
      getter program : Program
    end

    enum Kind
      Module
      Class
      Struct
      Enum
      Alias
      Annotation
    end

    struct TypeRef
      include JSON::Serializable

      getter kind : Kind
      getter full_name : String
      getter name : String
    end

    struct ConstDef
      include JSON::Serializable

      getter name : String
      getter value : String
      getter doc : String
      getter summary : String
    end

    struct MetaArg
      include JSON::Serializable

      getter name : String
      getter external_name : String
      getter restriction : String
    end

    struct Def
      include JSON::Serializable

      getter name : String
      getter doc : String
      getter summary : String
      getter? abstract : Bool
      getter args : Array(MetaArg)
      getter args_string : String
      getter location : Location
      getter def : MetaDef
    end

    struct MetaDef
      include JSON::Serializable

      getter name : String
      getter args : Array(MetaArg)
      getter return_type : String
      getter visibility : String
      getter body : String
    end

    class Program
      include JSON::Serializable

      getter name : String
      getter full_name : String
      getter? abstract : Bool
      getter kind : Kind
      getter ancestors : Array(TypeRef)
      getter locations : Array(Location)
      getter repository_name : String
      getter? program : Bool
      getter? enum : Bool
      getter? alias : Bool
      getter? const : Bool
      getter constants : Array(ConstDef)
      getter included_modules : Array(TypeRef)
      getter extended_modules : Array(TypeRef)
      getter class_methods : Array(MetaDef)
    end
  end
end
