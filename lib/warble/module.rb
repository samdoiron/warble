# frozen_string_literal: true

module Warble
  class Module
    def initialize(
        codes:,
        custom_sections:,
        datas:,
        elems:,
        exports:,
        funcs:,
        globals:,
        imports:,
        mems:,
        tables:,
        types:
      )
      @codes = codes
      @custom_sections = custom_sections
      @datas = datas
      @elems = elems
      @exports = exports
      @funcs = funcs
      @globals = globals
      @imports = imports
      @mems = mems
      @tables = tables
      @types = types
    end

    def instantiate
      ModuleInstance.new(self)
    end

    attr_reader :codes, :custom_sections, :datas, :elems, :exports, :funcs, :globals,
      :imports, :mems, :tables, :types
  end
end
