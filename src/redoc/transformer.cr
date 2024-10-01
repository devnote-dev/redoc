module Redoc
  # :nodoc:
  module Transformer
    def self.transform(main : Crystal::Program) : Library
      library = Library.new main.repository_name, main.body
      transform library, main.program
    end

    private def self.transform(library : Library, top_level : Crystal::Type) : Library
      if constants = top_level.constants
        constants.each do |const_def|
          library.constants << Const.new(const_def, nil)
        end
      end

      if class_methods = top_level.class_methods
        class_methods.each do |method|
          library.defs << Def.new(method, nil)
        end
      end

      if macros = top_level.macros
        macros.each do |method|
          library.macros << Macro.new(method, nil)
        end
      end

      if types = top_level.types
        types.each { |inner| transform inner, library, true }
      end

      library
    end

    private def self.transform(type : Crystal::Type, namespace : Namespace, top_level : Bool) : Nil
      case type.kind
      in .module?     then namespace.modules << transform_module type, top_level
      in .class?      then namespace.classes << transform_class type, top_level
      in .struct?     then namespace.structs << transform_struct type, top_level
      in .enum?       then namespace.enums << transform_enum type, top_level
      in .alias?      then namespace.aliases << transform_alias type, top_level
      in .annotation? then namespace.annotations << transform_annotation type, top_level
      end
    end

    private def self.transform_module(type : Crystal::Type, top_level : Bool) : Module
      mod = Module.new(
        type.html_id,
        type.path,
        type.name,
        type.full_name,
        locations: type.locations,
        summary: type.summary,
        doc: type.doc,
        top_level: top_level,
      )
      ref = TypeRef.new(mod.html_id, mod.name, mod.full_name, :module)

      if constants = type.constants
        constants.each do |const|
          mod.constants << Const.new(const, ref)
        end
      end

      if included = type.included_modules
        mod.includes = included
      end

      if extended = type.extended_modules
        mod.extends = extended
      end

      {% for method in %w[class_methods instance_methods] %}
        if methods = type.{{method.id}}
          methods.each do |method|
            mod.{{method.id}} << Def.new(method, ref)
          end
        end
      {% end %}

      if methods = type.macros
        methods.each do |method|
          mod.macros << Macro.new(method, ref)
        end
      end

      if types = type.types
        types.each { |inner| transform inner, mod, false }
      end

      mod
    end

    {% for type in %w[Class Struct] %}
      private def self.transform_{{type.downcase.id}}(type : Crystal::Type, top_level : Bool) : {{type.id}}
        cls = {{type.id}}.new(
          type.html_id,
          type.path,
          type.name,
          type.full_name,
          abstract: type.abstract?,
          locations: type.locations,
          summary: type.summary,
          doc: type.doc,
          top_level: top_level,
        )
        cls.parent = type.superclass
        ref = TypeRef.new(cls.html_id, cls.name, cls.full_name, :{{type.downcase.id}})

        if constants = type.constants
          constants.each do |const|
            cls.constants << Const.new(const, ref)
          end
        end

        if ancestors = type.ancestors
          cls.ancestors = ancestors
        end

        if included = type.included_modules
          cls.includes = included
        end

        if extended = type.extended_modules
          cls.extends = extended
        end

        {% for method in %w[constructors class_methods instance_methods] %}
          if methods = type.{{method.id}}
            methods.each do |method|
              cls.{{method.id}} << Def.new(method, ref)
            end
          end
        {% end %}

        if methods = type.macros
          methods.each do |method|
            cls.macros << Macro.new(method, ref)
          end
        end

        if types = type.types
          types.each { |inner| transform inner, cls, false }
        end

        cls
      end
    {% end %}

    private def self.transform_enum(type : Crystal::Type, top_level : Bool) : Enum
      {% begin %}
        type.responds_to?(:html_id) || raise "BUG: missing html_id for Crystal::Type enum"
        ref = TypeRef.new(type.html_id, type.name, type.full_name, :enum)

        if const_defs = type.constants
          constants = const_defs.map { |c| Const.new(c, ref) }
        else
          constants = [] of Const
        end

        %enum = Enum.new(
          type.html_id,
          type.path,
          type.name,
          type.full_name,
          constants,
          locations: type.locations,
          summary: type.summary,
          doc: type.doc,
          top_level: top_level,
        )

        if ancestors = type.ancestors
          %enum.ancestors = ancestors
        end

        {% for method in %w[constructors class_methods instance_methods] %}
          if methods = type.{{method.id}}
            methods.each do |method|
              %enum.{{method.id}} << Def.new(method, ref)
            end
          end
        {% end %}

        %enum
      {% end %}
    end

    private def self.transform_alias(type : Crystal::Type, top_level : Bool) : Alias
      Alias.new(
        type.html_id,
        type.path,
        type.name,
        type.full_name,
        type.aliased.as(String),
        locations: type.locations,
        summary: type.summary,
        doc: type.doc,
        top_level: top_level,
      )
    end

    private def self.transform_annotation(type : Crystal::Type, top_level : Bool) : Annotation
      Annotation.new(
        type.html_id,
        type.path,
        type.name,
        type.full_name,
        locations: type.locations,
        summary: type.summary,
        doc: type.doc,
        top_level: top_level,
      )
    end
  end
end
