# frozen_string_literal: true

module Warble
  class Decoder
    def initialize(binary)
      binary.force_encoding(Encoding::ASCII_8BIT)

      @binary = binary
      @offset = 0

      @codes = []
      @custom_sections = []
      @datas = []
      @elems = []
      @exports = []
      @funcs = []
      @globals = []
      @imports = []
      @mems = []
      @tables = []
      @types = []
    end

    def inspect = "Warble::Decoder"

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
      sections(id: 7) { export_section }
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

      Warble::Module.new(
        codes: @codes,
        custom_sections: @custom_sections,
        datas: @datas,
        elems: @elems,
        exports: @exports,
        funcs: @funcs,
        globals: @globals,
        imports: @imports,
        mems: @mems,
        tables: @tables,
        types: @types
      )
    end

    def magic = const("\x00asm".b)

    def version = const("\x01\x00\x00\x00".b)

    def custom_sections
      while peek_byte == 0
        id = byte
        size = u32
        next if size == 0
        @custom_sections << custom_section(id, size)
      end
    end

    def sections(id:)
      section_types = %w(custom type import function table memory global export start element code data data_count)
      while peek_byte == id
        _id = byte
        size = u32
        next if size == 0
        yield
      end
    end

    def custom_section(id, size)
      { id:, size:, data: bytes(size) }
    end

    def type_section
      @types = vec { func_type }
    end

    def func_type
      header = byte
      assert(header == 0x60, "expected functype header 0x60, got 0x#{header.to_s(16)} at offset #{@offset}")
      { in: result_type, out: result_type }
    end
    
    def result_type
      vec { val_type }
    end

    def val_type
      case b = byte
      when 0x7F then :i32
      when 0x7E then :i64
      when 0x7D then :f32
      when 0x7C then :f64
      when 0x7B then :v128
      when 0x70 then :funcref
      when 0x6f then :externref
      else
        raise RuntimeError, "invalid value type 0x#{b.to_s(16)}"
      end
    end

    def ref_type
      case b = byte
      when 0x70 then :funcref
      when 0x6f then :externref
      else
        binding.pry
        raise RuntimeError, "invalid ref type 0x#{b.to_s(16)}"
      end
    end

    def import_section
      @imports = vec { import }
    end

    def import
      { module: name, nm: name, desc: import_desc }
    end

    def import_desc
      case byte
      when 0x0 then [:func, type_idx]
      when 0x1 then [:table, table_type]
      when 0x2 then [:mem, mem_type]
      when 0x3 then [:global, global_type]
      end
    end

    def type_idx = u32

    def label_idx = u32
      
    def func_idx = u32

    def local_idx = u32

    def global_idx = u32

    def elem_idx = u32

    def mem_idx = u32

    def table_type
      { et: ref_type, limit: limits }
    end

    def limits 
      case b = byte
      when 0x0 then { min: u32 }
      when 0x1 then { min: u32, max: u32 }
      else
        raise RuntimeError, "invalid limits header #{b}"
      end
    end

    def mem_type = limits

    def global_type
      type = val_type

      case b = byte
      when 0x0 then [:const, type]
      when 0x1 then [:var, type]
      else
        raise "invalid mutability #{b}"
      end
    end

    def function_section
      @funcs += vec { type_idx }
    end

    def table_section
      @tables += vec { table_type }
    end

    def memory_section
      @mems += vec { mem_type }
    end

    def global_section
      @globals += vec { global }
    end

    def global
      { type: global_type, init: expr}
    end

    def expr
      instructions = []
      until peek_byte == 0x0b
        instructions << instr
      end
      _end = byte
      instructions
    end

    def instr
      case (opcode = byte)

      # Control instructions
      when 0x00 then :unreachable
      when 0x01 then :nop
      when 0x02 then [:block, block_type, expr]
      when 0x03 then [:loop, block_type, expr]
      when 0x04 
        raise
        if_else
      when 0x0c then [:br, label_idx]
      when 0x0d then [:br_if, label_idx]
      when 0x0e then [:br_table, vec { label_idx }, label_idx]
      when 0x0f then :return
      when 0x10 then [:call, func_idx]
      when 0x11 then
        y = type_idx
        x = type_idx
        [:call_indirect, x, y]

      # Reference instructions
      when 0xd0 then [:ref_null, ref_type]
      when 0xd1 then :ref_is_null
      when 0xd2 then [:ref_func, func_idx]

      # Parametric instructions
      when 0x1a then :drop
      when 0x1b then :select
      when 0x1c then [:select, vec { val_type }]

      # Variable instructions
      when 0x20 then [:local_get, local_idx]
      when 0x21 then [:local_set, local_idx]
      when 0x22 then [:local_tee, local_idx]
      when 0x23 then [:global_get, global_idx]
      when 0x24 then [:global_set, global_idx]

      # Table instructions
      when 0x25 then [:table_get, table_idx]
      when 0x26 then [:table_set, table_idx]
      when 0xfc
        case sub_instr = u32
        when 12 
          y = elem_idx
          x = table_idx
          [:table_init, x, y]
        when 13 then [:table_drop, elem_idx]
        when 14 then [:table_copy, table_idx, table_idx]
        when 15 then [:table_grow, table_idx]
        when 16 then [:table_size, table_idx]
        when 17 then [:table_fill, table_idx]
        else
          raise RuntimeError, "unknown table function #{sub_instr}"
        end

      # Memory instructions
      when 0x28 then [:i32_load, mem_arg]
      when 0x29 then [:i64_load, mem_arg]
      when 0x2a then [:f32_load, mem_arg]
      when 0x2b then [:f64_load, mem_arg]
      when 0x2c then [:i32_load8_s, mem_arg]
      when 0x2d then [:i32_load8_u, mem_arg]
      when 0x2e then [:i32_load16_s, mem_arg]
      when 0x2f then [:i32_load16_u, mem_arg]
      when 0x30 then [:i64_load8_s, mem_arg]
      when 0x31 then [:i64_load8_u, mem_arg]
      when 0x32 then [:i64_load16_s, mem_arg]
      when 0x33 then [:i64_load16_u, mem_arg]
      when 0x34 then [:i64_load32_s, mem_arg]
      when 0x35 then [:i64_load32_u, mem_arg]
      when 0x36 then [:i32_store, mem_arg]
      when 0x37 then [:i64_store, mem_arg]
      when 0x38 then [:f32_store, mem_arg]
      when 0x39 then [:f64_store, mem_arg]
      when 0x3a then [:i32_store8, mem_arg]
      when 0x3b then [:i32_store16, mem_arg]
      when 0x3c then [:i64_store8, mem_arg]
      when 0x3d then [:i64_store16, mem_arg]
      when 0x3e then [:i64_store32, mem_arg]
      when 0x3f
        assert(byte == 0x00, "memory_size must reference memory 0")
        :memory_size
      when 0x40
        assert(byte == 0x00, "memory_grow must reference memory 0")
        :memory_grow
      when 0xfc
        case sub_instr = u32
        when 8
          data_idx = u32
          assert(byte == 0x00)
          [:memory_init, data_idx]
        when 9 then [:data_drop, data_idx]
        when 10
          assert(byte == 0x00)
          assert(byte == 0x00)
          :memory_copy
        when 11
          assert(byte == 0x00)
          :memory_fill
        else
          raise RuntimeError, "unknown memory function #{sub_instr}"
        end

      # Numeric instructions
      when 0x41 then [:i32_const, i32]
      when 0x42 then [:i64_const, i64]
      when 0x43 then [:f32_const, f32]
      when 0x44 then [:f64_const, f64]
      when 0x45 then :i32_eqz
      when 0x46 then :i32_eq
      when 0x47 then :i32_neq
      when 0x48 then :i32_lt_s
      when 0x49 then :i32_lt_u
      when 0x4a then :i32_gt_s
      when 0x4b then :i32_gt_u
      when 0x4c then :i32_le_s
      when 0x4d then :i32_le_u
      when 0x4e then :i32_ge_s
      when 0x4f then :i32_ge_u
      when 0x50 then :i64_eqz
      when 0x51 then :i64_eq
      when 0x52 then :i64_ne
      when 0x53 then :i64_lt_s
      when 0x54 then :i64_lt_u
      when 0x55 then :i64_gt_s
      when 0x56 then :i64_gt_u
      when 0x57 then :i64_le_s
      when 0x58 then :i64_le_u
      when 0x59 then :i64_ge_s
      when 0x5a then :i64_ge_u
      when 0x5b then :f32_eq
      when 0x5c then :f32_ne
      when 0x5d then :f32_lt
      when 0x5e then :f32_gt
      when 0x5f then :f32_le
      when 0x60 then :f32_ge
      when 0x61 then :f64_eq
      when 0x62 then :f64_ne
      when 0x63 then :f64_lt
      when 0x64 then :f64_gt
      when 0x65 then :f64_le
      when 0x66 then :f64_ge
      when 0x67 then :i32_clz
      when 0x68 then :i32_ctz
      when 0x69 then :i32_popcnt
      when 0x6a then :i32_add
      when 0x6b then :i32_sub
      when 0x6c then :i32_mul
      when 0x6d then :i32_div_s
      when 0x6e then :i32_div_u
      when 0x6f then :i32_rem_s
      when 0x70 then :i32_rem_u
      when 0x71 then :i32_and
      when 0x72 then :i32_or
      when 0x73 then :i32_xor
      when 0x74 then :i32_shl
      when 0x75 then :i32_shr_s
      when 0x76 then :i32_shr_u
      when 0x77 then :i32_rotl
      when 0x78 then :i32_rotr
      when 0x79 then :i64_clz
      when 0x7a then :i64_ctz
      when 0x7b then :i64_popcnt
      when 0x7c then :i64_add
      when 0x7d then :i64_sub
      when 0x7e then :i64_mul
      when 0x7f then :i64_div_s
      when 0x80 then :i64_div_u
      when 0x81 then :i64_rem_s
      when 0x82 then :i64_rem_u
      when 0x83 then :i64_and
      when 0x84 then :i64_or
      when 0x85 then :i64_xor
      when 0x86 then :i64_shl
      when 0x87 then :i64_shr_s
      when 0x88 then :i64_shr_u
      when 0x89 then :i64_rotl
      when 0x8a then :i64_rotr
      when 0x8b then :f32_abs
      when 0x8c then :f32_neg
      when 0x8d then :f32_ceil
      when 0x8e then :f32_floor
      when 0x8f then :f32_trunc
      when 0x90 then :f32_nearest
      when 0x91 then :f32_sqrt
      when 0x92 then :f32_add
      when 0x93 then :f32_sub
      when 0x94 then :f32_mul
      when 0x95 then :f32_div
      when 0x96 then :f32_min
      when 0x97 then :f32_max
      when 0x98 then :f32_copysign
      when 0x99 then :f64_abs
      when 0x9a then :f64_neg
      when 0x9b then :f64_ceil
      when 0x9c then :f64_floor
      when 0x9d then :f64_trunc
      when 0x9e then :f64_nearest
      when 0x9f then :f64_sqrt
      when 0xa0 then :f64_add
      when 0xa1 then :f64_sub
      when 0xa2 then :f64_mul
      when 0xa3 then :f64_div
      when 0xa4 then :f64_min
      when 0xa5 then :f64_max
      when 0xa6 then :f64_copysign
      when 0xa7 then :i32_wrap_i64
      when 0xa8 then :i32_trunc_f32_s
      when 0xa9 then :i32_trunc_f32_u
      when 0xaa then :i32_trunc_f64_s
      when 0xab then :i32_trunc_f64_u
      when 0xac then :i64_extend_i32_s
      when 0xad then :i64_extend_i32_u
      when 0xae then :i64_trunc_f32_s
      when 0xaf then :i64_trunc_f32_u
      when 0xb0 then :i64_trunc_f64_s
      when 0xb1 then :i64_trunc_f64_u
      when 0xb2 then :f32_convert_i32_s
      when 0xb3 then :f32_convert_i32_u
      when 0xb4 then :f32_convert_i64_s
      when 0xb5 then :f32_convert_i64_u
      when 0xb6 then :f32_demote_f64
      when 0xb7 then :f64_convert_i32_s
      when 0xb8 then :f64_convert_i32_u
      when 0xb9 then :f64_convert_i64_s
      when 0xba then :f64_convert_i64_u
      when 0xbb then :f64_promote_f32
      when 0xbc then :i32_reinterpret_f32
      when 0xbd then :i64_reinterpret_f64
      when 0xbe then :f32_reinterpret_i32
      when 0xbf then :f64_reinterpret_i64
      when 0xc0 then :i32_extend8_s
      when 0xc1 then :i32_extend16_s
      when 0xc2 then :i64_extend8_s
      when 0xc3 then :i64_extend16_s
      when 0xc4 then :i64_extend32_s
      when 0xfc
        case sub_instr = u32
        when 0 then :i32_trunc_sat_f32_s
        when 1 then :i32_trunc_sat_f32_u
        when 2 then :i32_trunc_sat_f64_s
        when 3 then :i32_trunc_sat_f64_u
        when 4 then :i64_trunc_sat_f32_s
        when 5 then :i64_trunc_sat_f32_u
        when 6 then :i64_trunc_sat_f64_s
        when 7 then :i64_trunc_sat_f64_u
        else
          raise RuntimeError, "unknown saturating truncation instruction #{sub_instr}"
        end
      when 0xfd
        # Vector instructions
        todo("vector instructions")
      else
        binding.pry
        raise ArgumentError, "unknown instruction: 0x#{opcode.to_s(16)}"
      end
    end

    def mem_arg
      { align: u32, offset: u32 }
    end

    def if_else
      block = [:if]
      instructions = []

      loop do
        instructions << instr

        # start of else section
        if peek_byte == 0x05
          byte
          block << instructions
        end

        # end of block
        if peek_byte == 0x0b
          byte
          block << instructions
          break
        end
      end

      block
    end

    def block_type
      case byte
      when 0x40 then :empty

      # DUP: Duplicated from val_type
      when 0x7F then :i32
      when 0x7E then :i64
      when 0x7D then :f32
      when 0x7C then :f64
      when 0x7B then :v128
      when 0x70 then :funcref
      when 0x6f then :externref
      else
        s33
      end
    end

    def parse_until(end_byte)
      yield until peek_byte == end_byte
    end

    def export_section
      @exports += vec { export }
    end

    def export = { name: name, desc: export_desc }

    def name = vec { byte }.pack("C*")

    def export_desc
      case b = byte
      when 0x00 then [:func, func_idx]
      when 0x01 then [:table, table_idx]
      when 0x02 then [:mem, mem_idx]
      when 0x03 then [:global, global_idx]
      else
        raise RuntimeError "unknown exportdesc type 0x#{b.to_s(16)}"
      end
    end

    def start_section = todo

    def element_section
      @elems += vec { elem }
    end

    def elem
      # TODO: Can this be cleaner if we treat it as a bit field?
      case elem_type = u32
      when 0
        offset = expr
        init = vec { func_idx }.map { [:ref_func, _1 ] }
        { type: :funcref, init: init, mode: :active, table: 0, offset: }
      when 1
        todo
      when 2
        todo
      when 3
        todo
      when 4
        todo
      when 5
        todo
      when 6
        todo
      when 7
        todo
      else
        raise RuntimeError, "unknown elem type 0x#{elem_type.to_s(16)}"
      end
    end

    def code_section
      @codes += vec { code }
    end

    def code
      size = u32
      func
    end

    def func
      ls = vec { locals }.flatten
      { locals: ls, expr: }
    end

    def locals
      count = u32
      type = val_type
      [type] * count
    end

    def data_section
      @datas += vec { data }
    end

    def data
      type = u32
      case type
      when 0
        offset = expr
        bytes = vec { byte }
        { init: bytes, memory: 0, offset:, mode: :active }
      when 1 then todo
      when 2 then todo
      else
        raise RuntimeError "invalid data-segment type 0x#{type.to_s(16)}"
      end
    end

    def data_count_section = todo

    def u32
      value = unsigned_leb128
      assert_bitsize 32, value
      value
    end

    def i32
      value = signed_leb128
      assert_bitsize 32, value
      value
    end

    def i64
      value = signed_leb128
      assert_bitsize 64, value
      value
    end

    def s33
      value = unsigned_leb128
      assert_bitsize 33, value
      value
    end

    def vec
      length = u32
      (0...length).map { yield }
    end

    def unsigned_leb128
      value, bytes = Leb128.decode_unsigned(@binary[@offset..])
      value
    ensure
      @offset += bytes
      invariant @offset <= @binary.length - 1
    end

    def signed_leb128
      value, bytes = Leb128.decode_signed(@binary[@offset..])
      value
    ensure
      @offset += bytes
      invariant @offset <= @binary.length - 1
    end

    def byte
      assert @offset <= @binary.length - 2, "failed to pop byte, end of string"
      @binary.getbyte(@offset)
    ensure
      @offset += 1
      invariant @offset <= @binary.length - 1
    end

    def bytes(size)
      assert @offset <= @binary.length - (size + 1), "failed to pop #{size} bytes, end of string"
      result = @binary[@offset...@offset+size]
    ensure
      @offset += 1
      invariant @offset <= @binary.length - 1
      invariant result.bytesize == size
    end

    def peek_byte
      @binary.getbyte(@offset)
    end

    def const(expected)
      unless expected.encoding == Encoding::ASCII_8BIT
        raise ArgumentError, "expected binary string" 
      end

      actual = @binary[@offset..@offset+expected.bytesize - 1]
      assert actual == expected, "expected #{expected.inspect}, found #{actual.inspect}"
    ensure
      @offset += expected.bytesize
      invariant @offset <= @binary.length - 1
    end

    def assert_bitsize(bits, value)
      assert value < 2**bits, "expected #{bits} bit integer, got #{value}"
    end

    def assert(condition, error_message)
      raise Error, error_message unless condition
    end

    def invariant(condition)
      raise RuntimeError, "invariant failed" unless condition
    end

    def todo(message = nil)
      if message
        raise RuntimeError, "todo: #{message}"
      else
        raise RuntimeError, "todo"
      end
    end
  end
end