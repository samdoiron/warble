# frozen_string_literal: true

module Warble
  class Decoder
    def initialize(binary)
      binary.force_encoding(Encoding::ASCII_8BIT)

      @binary = binary
      @offset = 0

      @custom_sections = []
    end

    def module
      magic
      version

      custom_sections
      sections(id: 1) { type_section }
      custom_sections
      sections(id: 2) { import_section }
      custom_sections
      sections(id: 3) { function_section }
      custom_sections
      sections(id: 4) { table_section }
      custom_sections
      sections(id: 5) { memory_section }
      custom_sections
      sections(id: 6) { global_section }
      custom_sections
      sections(id: 7) { table_section }
      custom_sections
      sections(id: 8) { start_section }
      custom_sections
      sections(id: 9) { element_section }
      custom_sections
      sections(id: 10) { code_section }
      custom_sections
      sections(id: 11) { data_section }
      custom_sections
      sections(id: 12) { data_count_section }
      custom_sections
    end

    def magic = const("\x00asm")

    def version = const("\x01\x00\x00\x00")

    def custom_sections
      while peek_byte == 0
        _id = byte
        size = u32
        @custom_sections << custom_section(size)
      end
    end

    def sections(id:)
      while peek_byte == id
        _id = byte
        _size = u32
        yield
      end
    end

    def custom_section(size)

    end

    def type_section = todo

    def type_section = todo

    def import_section = todo

    def function_section = todo

    def table_section = todo

    def memory_section = todo

    def global_section = todo

    def export_section = todo

    def start_section = todo

    def element_section = todo

    def code_section = todo

    def data_section = todo

    def data_count_section = todo

    def u32
      value = unsigned_leb128
      assert_bitsize 32, value
      value
    end

    def vec
    end

    def unsigned_leb128
      value, bytes = Leb128.decode_unsigned(@binary)
      value
    ensure
      @offset += bytes
      invariant @offset <= @binary.length - (count + 1)
    end

    def byte
      assert @offset <= @binary.length - 2, "failed to pop byte, end of string"
      @binary[@offset]
    ensure
      @offset += 1
      invariant @offset <= @binary.length - 1
    end

    def bytes(size)
      assert @offset <= @binary.length - (size + 1), "failed to pop #{size} bytes, end of string"
      result = @binary[@offset..@offset+size]
    ensure
      @offset += 1
      invariant @offset <= @binary.length - 1
      invariant result.bytesize == size
    end

    def peek_byte
      @binary[@offset]
    end

    def const(expected)
      actual = @binary[@offset..@offset+expected.bytesize]
      assert actual == expected, "expected #{expected.inspect}, found #{actual.inspect}"
    ensure
      @offset += expected.bytesize
      invariant @offset <= @binary.length - 1
    end

    def const(expected)
      actual = @binary[@offset..@offset+expected.bytesize]
      assert actual == expected, "expected #{expected.inspect}, found #{actual.inspect}"
    ensure
      @offset 
    end

    def assert_bitsize(bits, value)
    end

    def assert_bitsize(bits, value)
      assert value < 2**bits, "expected #{bits} bit integer, got #{value}"
    end

    def assert(condition, error_message)
      raise Error, error_message unless condition
    end

    def invariant(condition, invariant_name)
      raise RuntimeError, "invariant failed"
    end

    def todo
      raise RuntimeError, "todo"
    end
  end
end