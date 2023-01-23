# frozen_string_literal: true

require_relative "warble/version"

module Warble
  class Error < StandardError; end

  autoload :Decoder, 'warble/decode'
  autoload :Leb128, 'warble/leb128'
  autoload :Module, 'warble/module'
end
