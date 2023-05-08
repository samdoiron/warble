# frozen_string_literal: true

require "test_helper"

class TestLeb128 < Minitest::Test

  def test_encode_unsigned_single_byte
    (0..127).each do |byte|
      assert_equal byte.chr, Warble::Leb128.encode_unsigned(byte)
    end
  end

  def test_encode_unsigned_multibyte
    (128..256).each do |byte|
      encoded = Warble::Leb128.encode_unsigned(byte)
      assert_equal 2, encoded.bytesize
    end
  end

  def test_decode_unsigned_single_byte
    (0..127).each do |byte|
      encoded, bytes = Warble::Leb128.decode_unsigned(byte.chr)
      assert_equal byte, encoded
      assert_equal 1, bytes
    end
  end

  def test_unsigned_encode_outputs_ascii_8bit
    encoded = Warble::Leb128.encode_unsigned(123)
    assert_equal Encoding::ASCII_8BIT, encoded.encoding
  end

  def test_unsigned_encode_and_decode_are_symmetric
    100.times do 
      number = rand(0..1_000_000_000_000)
      encoded = Warble::Leb128.encode_unsigned(number)
      decoded, _ = Warble::Leb128.decode_unsigned(encoded)

      assert_equal number, decoded
    end
  end

  def test_unsigned_decode_is_uneffected_by_trailing_values
    100.times do 
      number = rand(0..1_000_000_000_000)
      encoded = Warble::Leb128.encode_unsigned(number)

      before_val, before_count = Warble::Leb128.decode_unsigned(encoded)
      encoded += "nonsense"
      after_val, after_count = Warble::Leb128.decode_unsigned(encoded)

      assert_equal before_val, after_val
      assert_equal before_count, after_count
    end
  end
end
