library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity RAM_8x256 is
	port(
		CLK     : in std_logic;
		DIN     : in std_logic_vector(7 downto 0);
		ADDR    : in std_logic_vector(7 downto 0);
		WE      : in std_logic;
		DOUT    : out std_logic_vector(7 downto 0);
		POS_255 : out std_logic_vector(7 downto 0)
	);
end RAM_8x256;

architecture rtl of RAM_8x256 is
    
	type RAM_t is array(0 to 255) of std_logic_vector(7 downto 0);
	signal read_address : std_logic_vector(7 downto 0) := (others => '0');

    -- trabalho_final.asm
    signal ram : RAM_t := (
        0   => "10110000", --  24:                    .global @preinit
        1   => "00100000", --  24:                    jmp 32
        2   => "10000101", --  31:                    .byte 133
        3   => "01111010", --  32:                    .byte 122
        4   => "11111111", --  33:                    .byte 255
        5   => "00100001", --  34:                    .byte 33
        6   => "01001101", --  35:                    .byte 77
        7   => "01100011", --  36:                    .byte 99
        8   => "01100111", --  37:                    .byte 103
        9   => "11001000", --  38:                    .byte 200
        10  => "00000101", --  39:                    .byte 5
        11  => "00011001", --  40:                    .byte 25
        12  => "00000000", --  43: actual_idx:        .byte 0x00
        13  => "00000000", --  44: actual_addr:       .byte 0x00
        14  => "00000000", --  45: actual_value:      .byte 0x00
        15  => "00000000", --  46: last_addr:         .byte 0x00
        16  => "00000000", --  47: last_value:        .byte 0x00
        17  => "00000001", --  48: first_print:       .byte 0x01
        18  => "00000000", -- 
        19  => "00000000", -- 
        20  => "00000000", -- 
        21  => "00000000", -- 
        22  => "00000000", -- 
        23  => "00000000", -- 
        24  => "00000000", -- 
        25  => "00000000", -- 
        26  => "00000000", -- 
        27  => "00000000", -- 
        28  => "00000000", -- 
        29  => "00000000", -- 
        30  => "00000000", -- 
        31  => "00000000", -- 
        32  => "10001111", --  52: preinit:           ld rd, @vector_pointer
        33  => "00000010", --  52: preinit:           2
        34  => "10001011", --  53:                    ld rc, @actual_idx
        35  => "00001100", --  53:                    12
        36  => "10101110", --  54:                    str rd, [rc]
        37  => "10110000", --  56:                    jmp @init_print_vector
        38  => "01110010", --  56:                    114
        39  => "10001111", --  58: start:             ld rd, @actual_idx
        40  => "00001100", --  58: start:             12
        41  => "10011111", --  59:                    ldr rd, [rd]
        42  => "10010011", --  60:                    ldr ra, [rd]
        43  => "10001011", --  62:                    ld rc, @actual_addr
        44  => "00001101", --  62:                    13
        45  => "10101110", --  63:                    str rd, [rc]
        46  => "10001011", --  64:                    ld rc, @actual_value
        47  => "00001110", --  64:                    14
        48  => "10100010", --  65:                    str ra, [rc]
        49  => "10001011", --  67:                    ld rc, @incidx
        50  => "00111111", --  67:                    63
        51  => "10001000", --  68:                    push rc
        52  => "10001011", --  70: storeminav:        ld rc, @last_addr
        53  => "00001111", --  70: storeminav:        15
        54  => "10101110", --  71:                    str rd, [rc]
        55  => "10001011", --  72:                    ld rc, @last_value
        56  => "00010000", --  72:                    16
        57  => "10100010", --  73:                    str ra, [rc]
        58  => "10001011", --  79: printlcd:          ld rc, @lcd
        59  => "11111111", --  79: printlcd:          255
        60  => "10100010", --  80:                    str ra, [rc]
        61  => "10001001", --  82:                    pop rc
        62  => "10111001", --  83:                    jmpr rc
        63  => "00101100", --  85: incidx:            inc rd
        64  => "10001011", --  86:                    ld rc, @vector_end
        65  => "00001100", --  86:                    12
        66  => "01101011", --  87:                    xor rc, rd
        67  => "10001011", --  88:                    ld rc, @end_vector
        68  => "01010011", --  88:                    83
        69  => "11001010", --  89:                    beq rc
        70  => "10010111", --  92:                    ldr rb, [rd]
        71  => "01100100", --  93:                    xor rb, ra
        72  => "10001011", --  94:                    ld rc, @savemin
        73  => "01001101", --  94:                    77
        74  => "11011010", --  95:                    blt rc
        75  => "10110000", --  96:                    jmp @incidx
        76  => "00111111", --  96:                    63
        77  => "10010011", --  98: savemin:           ldr ra, [rd]
        78  => "10001011", -- 100:                    ld rc, @incidx
        79  => "00111111", -- 100:                    63
        80  => "10001000", -- 101:                    push rc
        81  => "10110000", -- 103:                    jmp @storeminav
        82  => "00110100", -- 103:                    52
        83  => "10001111", -- 105: end_vector:        ld rd, @actual_idx
        84  => "00001100", -- 105: end_vector:        12
        85  => "10011111", -- 106:                    ldr rd, [rd]
        86  => "00101100", -- 107:                    inc rd
        87  => "10001011", -- 109:                    ld rc, @actual_idx
        88  => "00001100", -- 109:                    12
        89  => "10101110", -- 110:                    str rd, [rc]
        90  => "10001011", -- 112:                    ld rc, @vector_end
        91  => "00001100", -- 112:                    12
        92  => "01101011", -- 113:                    xor rc, rd
        93  => "10001011", -- 114:                    ld rc, @count_carry
        94  => "10010011", -- 114:                    147
        95  => "11001010", -- 115:                    beq rc
        96  => "10110000", -- 116:                    jmp @swap
        97  => "01100010", -- 116:                    98
        98  => "10000011", -- 120: swap:              ld ra, @actual_value
        99  => "00001110", -- 120: swap:              14
        100 => "10010000", -- 121:                    ldr ra, [ra]
        101 => "10000111", -- 122:                    ld rb, @last_addr
        102 => "00001111", -- 122:                    15
        103 => "10010101", -- 123:                    ldr rb, [rb]
        104 => "10100001", -- 124:                    str ra, [rb]
        105 => "10000011", -- 126:                    ld ra, @last_value
        106 => "00010000", -- 126:                    16
        107 => "10010000", -- 127:                    ldr ra, [ra]
        108 => "10000111", -- 128:                    ld rb, @actual_addr
        109 => "00001101", -- 128:                    13
        110 => "10010101", -- 129:                    ldr rb, [rb]
        111 => "10100001", -- 130:                    str ra, [rb]
        112 => "10110000", -- 132:                    jmp @start
        113 => "00100111", -- 132:                    39
        114 => "10001111", -- 136:                    ld rd, @vector_pointer
        115 => "00000010", -- 136:                    2
        116 => "10001011", -- 137:                    ld rc, @vector_end
        117 => "00001100", -- 137:                    12
        118 => "10010011", -- 139: print_vector:      ldr ra, [rd]
        119 => "00101100", -- 140:                    inc rd
        120 => "10000111", -- 142:                    ld rb, @print_vector_f
        121 => "01111101", -- 142:                    125
        122 => "10000100", -- 143:                    push rb
        123 => "10110000", -- 144:                    jmp @printlcd
        124 => "00111010", -- 144:                    58
        125 => "10001011", -- 147:                    ld rc, @vector_end
        126 => "00001100", -- 147:                    12
        127 => "01101011", -- 148:                    xor rc, rd
        128 => "10001011", -- 149:                    ld rc, @notfirstprint
        129 => "10000101", -- 149:                    133
        130 => "11001010", -- 150:                    beq rc
        131 => "10110000", -- 151:                    jmp @print_vector
        132 => "01110110", -- 151:                    118
        133 => "10000000", -- 154:                    push ra
        134 => "10000100", -- 155:                    push rb
        135 => "10000011", -- 156:                    ld ra, @first_print
        136 => "00010001", -- 156:                    17
        137 => "10010100", -- 157:                    ldr rb, [ra]
        138 => "00100110", -- 158:                    dec rb
        139 => "10100100", -- 159:                    str rb, [ra]
        140 => "10000101", -- 160:                    pop rb
        141 => "10000001", -- 161:                    pop ra
        142 => "10001111", -- 162:                    ld rd, @start
        143 => "00100111", -- 162:                    39
        144 => "10111110", -- 163:                    bz rd
        145 => "10110000", -- 164:                    jmp @end
        146 => "10100000", -- 164:                    160
        147 => "10000011", -- 167:                    ld ra, 0x00
        148 => "00000000", -- 167:                    0
        149 => "10000111", -- 168:                    ld rb, 0x02
        150 => "00000010", -- 168:                    2
        151 => "00000001", -- 171:                    add ra, rb
        152 => "10001011", -- 172:                    ld rc, @lcd
        153 => "11111111", -- 172:                    255
        154 => "10100010", -- 173:                    str ra, [rc]
        155 => "10001111", -- 175:                    ld rd, @init_print_vector
        156 => "01110010", -- 175:                    114
        157 => "11001100", -- 176:                    bcs rd
        158 => "10110000", -- 177:                    jmp @count_carry_loop
        159 => "10010111", -- 177:                    151
        160 => "11110000", -- 179: end:               halt
        others => (others => '0')
    );

begin

	process(CLK) is
	begin
		if falling_edge(CLK) then
			if WE = '1' then
				ram(to_integer(unsigned(ADDR))) <= DIN;
			end if;
			read_address <= ADDR;
		end if;
	end process;

	DOUT    <= ram(to_integer(unsigned(read_address)));
	POS_255 <= ram(255);

end architecture;
