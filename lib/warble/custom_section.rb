# frozen_string_literal: true

module Warble
  class CustomSection
    def initialize(name, content)
      @name = name
      @content = content
    end

    attr_reader :name, :content
  end
end