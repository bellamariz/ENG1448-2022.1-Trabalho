library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity u_alu is
	port (						 
		A 		: IN STD_LOGIC_VECTOR(7 downto 0);  -- Ri
		B 		: IN STD_LOGIC_VECTOR(7 downto 0);  -- Ri
		CMD 	: IN STD_LOGIC_VECTOR(7 downto 0);  -- opcode
		C_in 	: IN STD_LOGIC;  							-- overflow
		C_out : OUT STD_LOGIC; 							-- overflow
		FLAGS : OUT STD_LOGIC_VECTOR(4 downto 0);	-- flags (leds)
		S 		: OUT STD_LOGIC_VECTOR(7 downto 0)	-- saida
	);
end u_alu;

architecture Behavioral of u_alu is

	signal TEMP : STD_LOGIC_VECTOR(8 downto 0);

	-- flags da ALU (exibir nos leds)
	signal EQUAL : STD_LOGIC := '0';
	signal GREATER : STD_LOGIC := '0';
	signal SMALLER : STD_LOGIC := '0';
	signal ZERO : STD_LOGIC := '0';

begin
	process(A, B, CMD, C_in)
		variable tmp : STD_LOGIC_VECTOR(8 downto 0);
	begin 
		if (CMD(7 downto 4) = "0000") then 		-- ADD => S <= A + B
			TEMP <= STD_LOGIC_VECTOR( unsigned('0' & A) + unsigned('0' & B) );
		elsif (CMD(7 downto 4) = "0001") then 	-- SUB => S <= A - B
			TEMP <= STD_LOGIC_VECTOR( unsigned('0' & A) - unsigned('0' & B) );
			
		elsif (CMD(7 downto 4) = "0010") and (CMD(1 downto 0) = "00") then -- INC => S <= A + 1
			TEMP <= STD_LOGIC_VECTOR( unsigned('0' & A) + 1 );
		elsif (CMD(7 downto 4) = "0010") and (CMD(1 downto 0) = "01") then -- INCC => S <= A + CARRY
			tmp := x"00" & C_in;
			TEMP <= STD_LOGIC_VECTOR( unsigned('0' & A) + unsigned(tmp) );
		elsif (CMD(7 downto 4) = "0010") and (CMD(1 downto 0) = "10") then -- DEC => S <= A - 1
			TEMP <= STD_LOGIC_VECTOR( unsigned('0' & A) - 1 );
		elsif (CMD(7 downto 4) = "0010") and (CMD(1 downto 0) = "11") then -- DECC => S <= A - CARRY
			tmp := x"00" & C_in;
			TEMP <= STD_LOGIC_VECTOR( unsigned('0' & A) - unsigned(tmp) );
		
		elsif (CMD(7 downto 4) = "0011") then 	-- AND => S <= A AND B
			TEMP <=  ('0' & A) and ('0' & B);		
		elsif (CMD(7 downto 4) = "0100") then 	-- OR => S <= A OR B
			TEMP <=  ('0' & A) or ('0' & B);
		elsif (CMD(7 downto 4) = "0101") then 	-- NOT => S <= NOT A
			TEMP <=  not ('0' & A);		
		elsif (CMD(7 downto 4) = "0110") then 	-- XOR => S <= A XOR B
			TEMP <=  ('0' & A) xor ('0' & B); 
			
		elsif (CMD(7 downto 4) = "0111") and (CMD(1 downto 0) = "00") then -- ROL => S <= ROL A
			TEMP <= '0' & A(6 downto 0) & C_in;
		elsif (CMD(7 downto 4) = "0111") and (CMD(1 downto 0) = "01") then -- ROR => S <= ROR A
			TEMP <= '0' & C_in & A(7 downto 1); 
		elsif (CMD(7 downto 4) = "0111") and (CMD(1 downto 0) = "10") then -- LSL => S <= LSL A
			TEMP <= '0' & A(6 downto 0) & '0';
		elsif (CMD(7 downto 4) = "0111") and (CMD(1 downto 0) = "11") then -- LSR => S <= LSR A
			TEMP <= "00" & A(7 downto 1);
		
		end if;	
		
	end process;

	-- saida
	S <= TEMP(7 downto 0);
	C_out <= TEMP(8);
	
	-- flags
	EQUAL <= '1' when A = B else '0';
	GREATER <= '1' when A > B else '0';
	SMALLER <= '1' when A < B else '0';
	ZERO <= '1' when TEMP(7 downto 0) = x"00" else '0';
	FLAGS <= EQUAL & GREATER & SMALLER & ZERO & TEMP(8);

end Behavioral;

