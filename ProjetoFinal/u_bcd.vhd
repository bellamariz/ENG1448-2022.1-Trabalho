library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity u_bcd is
	port(
		CLK, RESET 	: in STD_LOGIC;
		START 		: in STD_LOGIC;
		BIN 			: in STD_LOGIC_VECTOR(7 downto 0);
		BCD2 			: out STD_LOGIC_VECTOR(3 downto 0);
		BCD1, BCD0 	: out STD_LOGIC_VECTOR(3 downto 0);
		READY 		: out STD_LOGIC;
		DONE_TICK 	: out STD_LOGIC
);
end u_bcd;

architecture Behavioral of u_bcd is

	type FSM_T is (IDLE, OP, DONE);
	signal STATE_REG, STATE_NEXT : FSM_T := IDLE;
	
	signal P2S_REG, P2S_NEXT : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
	signal N_REG, N_NEXT : UNSIGNED(3 downto 0) := (others => '0');
	signal BCD2_REG : UNSIGNED(3 downto 0) := (others => '0');
	signal BCD1_REG, BCD0_REG : UNSIGNED(3 downto 0) := (others => '0');
	signal BCD2_NEXT : UNSIGNED(3 downto 0) := (others => '0');
	signal BCD1_NEXT, BCD0_NEXT : UNSIGNED(3 downto 0) := (others => '0');
	signal BCD2_TMP : UNSIGNED(3 downto 0) := (others => '0');
	signal BCD1_TMP, BCD0_TMP : UNSIGNED(3 downto 0) := (others => '0');

begin
	
	-- state and data registers
	process(CLK, RESET)
	begin
		if rising_edge(CLK) then
			if (RESET = '1') then
				STATE_REG <=  IDLE;
				P2S_REG 	 <= (others => '0');
				N_REG 	 <= (others => '0');
				BCD2_REG  <= (others => '0');
				BCD1_REG  <= (others => '0');
				BCD0_REG  <= (others => '0');
			else
				STATE_REG <= STATE_NEXT;
				P2S_REG 	 <= P2S_NEXT;
				N_REG 	 <= N_NEXT;
				BCD2_REG  <= BCD2_NEXT;
				BCD1_REG  <= BCD1_NEXT;
				BCD0_REG  <= BCD0_NEXT;
			end if;
		end if;
	end process;
	
	-- fsmd next-state logic / data path operations
	process(STATE_REG, START, P2S_REG, N_REG, N_NEXT, BIN, BCD2_REG, BCD1_REG, BCD0_REG, BCD2_TMP, BCD1_TMP, BCD0_TMP)
	begin
		STATE_NEXT <= STATE_REG;
		READY <= '0';
		DONE_TICK <= '0';
		P2S_NEXT <= P2S_REG;
		N_NEXT <= N_REG;
		BCD2_NEXT <= BCD2_REG;
		BCD1_NEXT <= BCD1_REG;
		BCD0_NEXT <= BCD0_REG;
		
		case STATE_REG is
			when IDLE =>
				READY <= '1';
				
				if (START = '1') then
					BCD2_NEXT 	<= (others => '0');
					BCD1_NEXT 	<= (others => '0');
					BCD0_NEXT 	<= (others => '0');
					N_NEXT 	 	<= "1000"; -- index'length;
					P2S_NEXT  	<= BIN; -- input shift register
					STATE_NEXT 	<= OP;
				end if;
				
			-- shift 4 BCD digits
			when OP =>
				BCD2_NEXT <= BCD2_TMP(2 downto 0) & BCD1_TMP(3);
				BCD1_NEXT <= BCD1_TMP(2 downto 0) & BCD0_TMP(3);
				BCD0_NEXT <= BCD0_TMP(2 downto 0) & P2S_REG(7);
				-- shift input
				P2S_NEXT <= P2S_REG(6 downto 0) & '0';
				-- iteration counter
				N_NEXT <= N_REG - 1;
				
				if (N_NEXT = 0) then
					STATE_NEXT <= DONE;
				end if;
				
			when done =>
				STATE_NEXT <= IDLE;
				DONE_TICK <= '1';
			
			when others =>
				STATE_NEXT <= IDLE;
		end case;
	end process;
	-- data path function units
	-- four BCD adjustment circuits
	BCD0_TMP <= BCD0_REG + 3 when BCD0_REG > 4 else BCD0_REG;
	BCD1_TMP <= BCD1_REG + 3 when BCD1_REG > 4 else BCD1_REG;
	BCD2_TMP <= BCD2_REG + 3 when BCD2_REG > 4 else BCD2_REG;
	
	-- output
	BCD0 <= STD_LOGIC_VECTOR(BCD0_REG);
	BCD1 <= STD_LOGIC_VECTOR(BCD1_REG);
	BCD2 <= STD_LOGIC_VECTOR(BCD2_REG);

end Behavioral;

