library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity u_ram is
	port(
        CLK     : in std_logic;
        DIN     : in std_logic_vector(7 downto 0);
        ADDR    : in std_logic_vector(7 downto 0);
        WE      : in std_logic;
        DOUT    : out std_logic_vector(7 downto 0);
        POS_255 : out std_logic_vector(7 downto 0)
	);
end u_ram;

architecture rtl of u_ram is
    
    type RAM_t is array(0 to 255) of std_logic_vector(7 downto 0);
    signal read_address : std_logic_vector(7 downto 0) := (others => '0');
    
    signal ram : RAM_t := (
         0 =>  "10000011", -- LD  Ra, 5
         1 =>  "00000101", -- 5
         2 =>  "10000111", -- LD  Rb, 10
         3 =>  "00001010", -- 10
         4 =>  "10001011", -- LD  Rc, 246
         5 =>  "11110110", -- 246
			6 =>  "10001111", -- LD  Rd, 255
			7 =>  "11111111", -- 255  
			8 =>  "00000010", -- ADD Ra, Rc 	--> Ra = 5 + 246 = 251 --> FLAG LESS antes, FLAG GREATER depois
			9 =>  "10100011", -- STR Ra, Rd	--> ram(255) <= Ra
			10 => "10000000", -- PUSH Ra 		--> SP -> 254 - 1 = 253
			11 => "00000110", -- ADD Rb, Rc 	--> Rb = 10 + 246 = 0 com FLAG OVERFLOW
			12 => "10100111", -- STR Rb, Rd	--> ram(255) <= Rb
			13 => "01110101", -- ROR Rb --> ROR(Rb) = 10000000
			14 => "10100111", -- STR Rb, Rd	--> ram(255) <= Rb
			-- TODO: CONTINUAR
			others => "00000000"
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