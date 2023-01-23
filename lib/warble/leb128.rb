# frozen_string_literal

module Warble
  module Leb128
    extend self

    def decode_unsigned(binary)
      result = 0
      byte_count = 0

      binary.each_byte do |byte|
        high_bit = byte[7]
        low_bits = byte[0..6]
        result |= low_bits << (byte_count * 7)

        break unless high_bit == 1

        byte_count += 1
      end
      
      [result, byte_count]
    end

    def encode_unsigned(number)
      raise ArgumentError if number < 0

      result = String.new(encoding: Encoding::ASCII_8BIT)

      loop do
        byte = number[0..6]
        number >>= 7

        if number != 0
          byte |= 0b1000_0000
        end

        result << byte

        break if number == 0
      end

      result.freeze
    end
  end
end