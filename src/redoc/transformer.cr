module Redoc
  # :nodoc:
  class Transformer
    @program : Program
    @top_level : Bool

    def self.transform(proj : Crystal::Project) : Program
      new(proj.repository_name, proj.body).transform(proj.program)

      @program
    end

    private def initialize(name : String, description : String)
      @program = Program.new name, description
      @top_level = true
    end

    def transform(top_level : Crystal::Program) : Nil
      if constants = top_level.constants
        constants.each do |const_def|
          @program.constants << Const.new(const_def)
        end
      end

      if class_methods = top_level.class_methods
        class_methods.each do |method|
          @program.defs << Def.new(method)
        end
      end

      if macros = top_level.macros
        macros.each do |method|
          @program.macros << Macro.new(method)
        end
      end

      if types = top_level.types
        types.each do |type|
          case type.kind
          in .module?     then transform module: type
          in .class?      then transform class: type
          in .struct?     then transform struct: type
          in .enum?       then transform enum: type
          in .alias?      then transform alias: type
          in .annotation? then transform annotation: type
          end
        end
      end
    end

    def transform(*, module type : Crystal::Program) : Nil
    end

    def transform(*, class type : Crystal::Program) : Nil
      cls = Class.new(type.name, type.full_name, type.summary, type.doc, @top_level)
      cls.parent = type.superclass
      cls.locations = type.locations

      if methods = type.constructors
        methods.each do |method|
          cls.constructors << Def.new(method, false)
        end
      end

      @program.classes << cls
    end

    def transform(*, struct type : Crystal::Program) : Nil
    end

    def transform(*, enum type : Crystal::Program) : Nil
    end

    def transform(*, alias type : Crystal::Program) : Nil
    end

    def transform(*, annotation type : Crystal::Program) : Nil
    end
  end
end
