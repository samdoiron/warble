# frozen_string_literal: true

module Warble
  class Interpreter
    def initialize(mod)
      @mod = mod
    end

    def run(export_name)
      export = mod.exports.find { _1[:name] == export_name }
      if export in { desc: [:func, index] }
        run_func(index)
      else
        raise ArgumentError, "#{export_name} is not a valid exported function"
      end
    end

    private

    def run_func(index)
      type = mod.types[mod.funcs[index]]
      mod.codes[index] => { locals:, expr: }
      binding.pry
    end

    attr_reader :mod
  end
end