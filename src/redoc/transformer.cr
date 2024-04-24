module Redoc
  # :nodoc:
  module Transformer
    def self.transform(main : Crystal::Program) : Project
      project = Project.new main.repository_name, main.body
      transform project, main.program
    end

    private def self.transform(project : Project, top_level : Crystal::Type) : Project
      if constants = top_level.constants
        constants.each do |const_def|
          project.constants << Const.new(const_def, true)
        end
      end

      if class_methods = top_level.class_methods
        class_methods.each do |method|
          project.defs << Def.new(method, true)
        end
      end

      if macros = top_level.macros
        macros.each do |method|
          project.macros << Macro.new(method, true)
        end
      end

      if types = top_level.types
        types.each do |type|
          case type.kind
          in .module?     then project.modules << transform_module type, true
          in .class?      then project.classes << transform_class type, true
          in .struct?     then project.structs << transform_struct type, true
          in .enum?       then project.enums << transform_enum type, true
          in .alias?      then project.aliases << transform_alias type, true
          in .annotation? then project.annotations << transform_annotation type, true
          end
        end
      end

      project
    end

    private def self.transform(type : Crystal::Type, namespace : Namespace) : Nil
      case type.kind
      in .module?     then namespace.modules << transform_module type, false
      in .class?      then namespace.classes << transform_class type, false
      in .struct?     then namespace.structs << transform_struct type, false
      in .enum?       then namespace.enums << transform_enum type, false
      in .alias?      then namespace.aliases << transform_alias type, false
      in .annotation? then namespace.annotations << transform_annotation type, false
      end
    end

    private def self.transform_module(type : Crystal::Type, top_level : Bool) : Module
      mod = Module.new(
        type.name,
        type.full_name,
        summary: type.summary,
        doc: type.doc,
        top_level: top_level,
      )
      mod.locations = type.locations

      if included = type.included_modules
        mod.includes = included
      end

      if extended = type.extended_modules
        mod.extends = extended
      end

      if types = type.types
        types.each { |inner| transform inner, mod }
      end

      mod
    end

    {% for type in %w[Class Struct] %}
      private def self.transform_{{type.downcase.id}}(type : Crystal::Type, top_level : Bool) : {{type.id}}
        cls = {{type.id}}.new(
          type.name,
          type.full_name,
          abstract: false,
          summary: type.summary,
          doc: type.doc,
          top_level: top_level,
        )
        cls.parent = type.superclass
        cls.locations = type.locations

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
              cls.{{method.id}} << Def.new(method, false)
            end
          end
        {% end %}

        if methods = type.macros
          methods.each do |method|
            cls.macros << Macro.new(method, false)
          end
        end

        if types = type.types
          types.each { |inner| transform inner, cls }
        end

        cls
      end
    {% end %}

    private def self.transform_enum(type : Crystal::Type, top_level : Bool) : Enum
      {% begin %}
        if const_defs = type.constants
          constants = const_defs.map { |c| Const.new(c, false) }
        else
          constants = [] of Const
        end

        %enum = Enum.new(
          type.name,
          type.full_name,
          constants,
          summary: type.summary,
          doc: type.doc,
          top_level: top_level,
        )
        %enum.locations = type.locations

        if ancestors = type.ancestors
          %enum.ancestors = ancestors
        end

        {% for method in %w[constructors class_methods instance_methods] %}
          if methods = type.{{method.id}}
            methods.each do |method|
              %enum.{{method.id}} << Def.new(method, false)
            end
          end
        {% end %}

        %enum
      {% end %}
    end

    private def self.transform_alias(type : Crystal::Type, top_level : Bool) : Alias
      {% begin %}
        %alias = Alias.new(
          type.name,
          type.full_name,
          type.aliased.as(String),
          summary: type.summary,
          doc: type.doc,
          top_level: top_level,
        )
        %alias.locations = type.locations

        %alias
      {% end %}
    end

    private def self.transform_annotation(type : Crystal::Type, top_level : Bool) : Annotation
      ann = Annotation.new(type.name, type.full_name, top_level: top_level)
      ann.locations = type.locations

      ann
    end
  end
end
