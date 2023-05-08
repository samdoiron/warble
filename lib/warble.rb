# frozen_string_literal: true

require_relative "warble/version"

module Warble
  class Error < StandardError; end

  autoload :Decoder, 'warble/decoder'
  autoload :ModuleInstance, 'warble/module_instance'
  autoload :Leb128, 'warble/leb128'
  autoload :Module, 'warble/module'
end
