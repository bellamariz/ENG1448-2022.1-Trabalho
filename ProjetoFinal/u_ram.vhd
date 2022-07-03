library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity u_ram is
	port(
        CLK     : in std_logic;
		RESET	: in std_logic;
        DIN     : in std_logic_vector(7 downto 0);
        ADDR    : in std_logic_vector(7 downto 0);
        WE      : in std_logic;
        DOUT    : out std_logic_vector(7 downto 0);
        POS_255 : out std_logic_vector(7 downto 0)
	);
end u_ram;

architecture rtl of u_ram is
    
    type RAM_t is array(0 to 255) of std_logic_vector(7 downto 0);
    
    signal ram : RAM_t := (
       0 =>  "10000011", -- LD  Ra, 5
       1 =>  "00000101", -- 5
       2 =>  "10000111", -- LD   Rb, 10
       3 =>  "00001010", -- 10
       4 =>  "10001011", -- LD   Rc, 246
       5 =>  "11110110", -- 246
		 6 =>  "10001111", -- LD   Rd, 255
		 7 =>  "11111111", -- 255  
		 8 =>  "00000010", -- ADD  Ra, Rc  --> Ra = 5 + 246 = 251 --> FLAG LESS antes
		 9 =>  "10100011", -- STR  Ra, Rd  --> ram(255) <= Ra (251)
		 10 => "10000000", -- PUSH Ra 	  --> SP -> 254 - 1 = 253
		 11 => "00000110", -- ADD  Rb, Rc  --> Rb = 10 + 246 = 0 com FLAG OVERFLOW
		 12 => "10100111", -- STR  Rb, Rd  --> ram(255) <= Rb (000)
		 13 => "01110101", -- ROR  Rb      --> ROR(Rb) = 128 (10000000)
		 14 => "10100111", -- STR  Rb, Rd  --> ram(255) <= Rb (128)
		 15 => "10001001", -- POP  Rc 	  --> SP -> 253 + 1 = 254, Rc = 251 (11111011)
		 16 => "10101011", -- STR  Rc, Rd  --> ram(255) <= Rc (251)
		 17 => "00010001", -- SUB  Ra, Rb  --> Ra = 251 - 128 = 123 (01111011) --> FLAG GREATER
		 18 => "10100011", -- STR  Ra, Rd  --> ram(255) <= Ra (123)
		 19 => "01100100", -- XOR  Rb, Ra  --> Rb = 251 (11111011)
		 20 => "10100111", -- STR  Rb, Rd  --> ram(255) <= Rb (251)
		 21 => "00111001", -- AND  Rc, Rb  --> Rc (251) & Rb (251) --> Rc <= 251 (11111011) --> FLAG EQUAL
		 22 => "10101011", -- STR  Rc, Rd  --> ram(255) <= Rc (251)
		 23 => "10000111", -- LD   Rb, 36
		 24 => "00100100", -- 36
		 25 => "10100111", -- STR  Rb, Rd  --> ram(255) <= Rb (036)
		 26 => "10001011", -- LD   Rc, 1
		 27 => "00000010", -- 1
		 28 => "10101011", -- STR  Rc, Rd  --> ram(255) <= Rc (008)
		 29 => "00101010", -- DEC  Rc		  --> Rc = Rc - 1 --> eventualmete, FLAG ZERO 
		 30 => "10101011", -- STR  Rc, Rd  --> ram(255) <= Rc = Rc - 1
		 31 => "10110110", -- BZ   Rb      --> if (zero) go to Rb (36) 
		 32 => "10110000", -- JMP  29		  --> else go to 29 (loop)
		 33 => "00011101", -- 29
		 34 => "11100000", -- DONT CARE
		 35 => "11100000", -- DONT CARE
		 36 => "01110010", -- LSL  Ra 	  --> LSL(Ra = 01111011) = 11110110 (246)
		 37 => "10100011", -- STR  Ra, Rd  --> ram(255) <= Ra (246)
		 --38 => "10110101", -- JMPR Rb
		 others => "11110000" -- HALT --> POS_255 = 240
    );
	
	signal READ_ADDR : std_logic_vector(7 downto 0) := (others => '0');
    
begin

	process(CLK, RESET) is
	begin
		if RESET = '1' then
			READ_ADDR <= (others => '0');
		elsif falling_edge(CLK) then
			READ_ADDR <= ADDR;
			if WE = '1' then
				ram(to_integer(unsigned(ADDR))) <= DIN;
			end if;
		end if;
    end process;
    
	DOUT    <= ram(to_integer(unsigned(READ_ADDR)));
	POS_255 <= ram(255);

end architecture;