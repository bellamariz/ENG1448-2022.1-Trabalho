library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity u_lcd is
	port(
		CLK 						: in STD_LOGIC;
		RESET						: in STD_LOGIC;
		NEW_IR_READY				: in STD_LOGIC;
		DATA_IN						: in STD_LOGIC_VECTOR(15 downto 0); -- IR & POS 255 
		DATA 						: out STD_LOGIC_VECTOR(3 downto 0);
		LCD_E, LCD_RS, LCD_RW 	    : out STD_LOGIC;
		SF 							: out STD_LOGIC;
		DISPLAY_READY				: out STD_LOGIC
	);

end u_lcd;

architecture Behavioral of u_lcd is

	----- 1) INTEGRATION WITH CPU

	-- funcao que converte string para std_logic_vector (mapeamento para tabela ASCII)
	function to_std_logic_vector(a : string) return std_logic_vector is
		 variable ret : std_logic_vector(a'length*8-1 downto 0);
	begin
		 for i in a'range loop
			  ret((i-1)*8+7 downto (i-1)*8) := std_logic_vector(to_unsigned(character'pos(a(i)), 8));
		 end loop;
		 return ret;
	end function to_std_logic_vector;
	

	-- LINHA 1: variaveis para decodificar IR para o LCD (linha 1)
	-- ALU
	constant str_add  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("add  Rx,Ry  ");
	constant str_sub  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("sub  Rx,Ry  ");
	constant str_inc  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("inc  Rx     ");
	constant str_incc : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("incc Rx     ");
	constant str_dec  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("dec  Rx     ");
	constant str_decc : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("decc Rx     ");
	constant str_and  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("and  Rx,Ry  ");
	constant str_or   : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("or   Rx,Ry  ");
	constant str_not  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("not  Rx     ");
	constant str_xor  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("xor  Rx,Ry  ");
	constant str_rol  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("rol  Rx     ");
	constant str_ror  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("ror  Rx     ");
	constant str_lsl  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("lsl  Rx     ");
	constant str_lsr  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("lsr  Rx     ");
	
	-- RAM
	constant str_push : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("push Rx     ");
	constant str_pop  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("pop  Rx     ");
	constant str_ld   : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("ld   Rx,0x--");
	constant str_ldr  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("ldr  Rx,Ry  ");
	constant str_str  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("str  Rx,Ry  ");
	
	-- JUMPS
	constant str_jmp  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("jmp  0x--   ");
	constant str_jmpr : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("jmpr Rx     ");
	constant str_bz   : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("bz   Rx     ");
	constant str_bnz  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("bnz  Rx     ");
	constant str_bcs  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("bcs  Rx     ");
	constant str_bcc  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("bcc  Rx     ");
	constant str_beq  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("beq  Rx     ");
	constant str_bneq : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("bneq Rx     ");
	constant str_bgt  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("bgt         ");
	constant str_bgez : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("bgez        ");
	constant str_blt  : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("blt         ");
	constant str_blez : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("blez        ");
	constant str_halt : STD_LOGIC_VECTOR(95 downto 0)  := to_std_logic_vector("halt        ");

	
	-- LINHA 2: variaveis para decodificar o ADDR
	
	-- 4-40 character display address: EM BRANCO
	-- 0-3 character display address: POS 255
	signal BCD2  : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
	signal BCD1  : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
	signal BCD0  : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
	signal BCD_START : STD_LOGIC := '0';
	signal BCD_READY : STD_LOGIC;
	signal BCD_DONE : STD_LOGIC;


	------- 2) LCD ORIGINAL
	
	type TIME_DATA_T is array (0 to 3) of STD_LOGIC_VECTOR(19 downto 0);
	signal TIME_DATA : TIME_DATA_T := (
		0 => STD_LOGIC_VECTOR(TO_UNSIGNED(205000, 20)), 
		1 => STD_LOGIC_VECTOR(TO_UNSIGNED(5000, 20)), 
		2 => STD_LOGIC_VECTOR(TO_UNSIGNED(2000, 20)), 
		3 => STD_LOGIC_VECTOR(TO_UNSIGNED(2000, 20)) 
	);
	
	type FSM_T is (IDLE, INIT_A, INIT_B, CONF_A, CONF_B, WAIT_CLEAR, WAIT_NEW_CMD, WRITE_A, WRITE_B);
	signal STATE : FSM_T := IDLE;
	
	-- tempo de espera para a inicializacao (passo 0)
	constant TIME_READY : STD_LOGIC_VECTOR(19 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(750000, 20));
	-- tempo para enviar os proximos 4 bits da nossa mensagem
	constant TIME_WAIT : STD_LOGIC_VECTOR(19 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(2000, 20));
	-- tempo para enviar comando de configuracao (40us / 20ns) = 2000
	constant TIME_CONFIG : STD_LOGIC_VECTOR(19 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(2000, 20));
	-- tempo para enviar comando de clear (1640us / 20ns) = 82000
	constant TIME_CLEAR : STD_LOGIC_VECTOR(19 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(82000, 20));
	-- tempo para esperar o enable virar '1'
	constant TIME_ENABLE : STD_LOGIC_VECTOR(19 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(12, 20));
	
	signal DATA_REG : STD_LOGIC_VECTOR (3 downto 0) := (others => '0');
	signal ENABLE  : STD_LOGIC := '0';
	signal REG_SELECT : STD_LOGIC := '0';
	signal TIME_RESET : STD_LOGIC := '0';
	signal UPPER : STD_LOGIC := '0';
	
	signal TIME_COUNT : STD_LOGIC_VECTOR (19 downto 0) := (others => '0');
	signal TIME_COUNT_LIMIT : STD_LOGIC_VECTOR (19 downto 0) := (others => '1');
	

	-- mensagem inicialmente em branco
	type MSG_T is array (0 to 79) of STD_LOGIC_VECTOR(3 downto 0);
	signal DATA_UPPER : MSG_T := (others => "0010");
	signal DATA_LOWER : MSG_T := (others => "0000");
	
	type CONFIG_T is array (0 to 3) of STD_LOGIC_VECTOR(3 downto 0);
	signal CONFIG_UPPER : CONFIG_T := (
		0 => "0010", -- 2 --> function set
		1 => "0000", -- 0 --> entry mode set
		2 => "0000", -- 0 --> display on/off
		3 => "0000" -- 0 --> clear
	);
	signal CONFIG_LOWER : CONFIG_T := (
		0 => "1000", -- 8
		1 => "0110", -- 6
		2 => "1100", -- C 
		3 => "0001" -- 1 
	); 
	--signal BIN : STD_LOGIC_VECTOR(7 downto 0) := DATA_IN(7 downto 0);
	
begin

	bcd : entity work.u_bcd(Behavioral)
		port map (
			CLK			=> CLK,
			RESET			=> RESET,
			START 		=> BCD_START,
			BIN 			=> DATA_IN(7 downto 0),
			BCD2 			=> BCD2, 
			BCD1			=> BCD1,	
			BCD0			=> BCD0,	
			READY 		=> BCD_READY,
			DONE_TICK 	=> BCD_DONE
		);
	
	
	process(CLK, RESET)
	begin
		if RESET = '1' then
			TIME_COUNT <= (others => '0');
		elsif rising_edge(CLK) then
			if (TIME_RESET = '1') then
				TIME_COUNT <= (others => '0');
			else
				TIME_COUNT <= STD_LOGIC_VECTOR( unsigned(TIME_COUNT) + 1 );
			end if;
		end if;
	end process;
	
	maq_estado : process(CLK, RESET)
		variable IDX : natural;
		variable STR_LCD : STD_LOGIC_VECTOR(95 downto 0);
	begin
		if RESET = '1' then
			STATE <= IDLE;
		
		elsif rising_edge(CLK) then
			case STATE is
				when IDLE =>
					DISPLAY_READY <= '0';
					REG_SELECT <= '0';
					ENABLE <= '0';
					IDX := 0;
					TIME_COUNT_LIMIT <= TIME_READY;
					DATA_REG <= "0011"; -- data = 3h
					if (TIME_RESET = '1') then
						STATE <= INIT_A;
						TIME_COUNT_LIMIT <= TIME_ENABLE; -- wait 12 cycles
					end if;
					
				when INIT_A =>
					DISPLAY_READY <= '0';
					ENABLE <= '1';
					if (TIME_RESET = '1') then 
						TIME_COUNT_LIMIT <= TIME_DATA(IDX);
						IDX := IDX + 1;
						STATE <= INIT_B;
					end if;
					
				when INIT_B =>
					DISPLAY_READY <= '0';
					ENABLE <= '0';
					if (IDX < 3) then
						DATA_REG <= "0011"; -- data = 3h
					elsif (IDX = 3) then
						DATA_REG <= "0010"; -- data = 2h
					else
						DATA_REG <= "0010"; -- data = 2h (0x28)
					end if;
					
					if (TIME_RESET = '1') then
						TIME_COUNT_LIMIT <= TIME_ENABLE; -- wait 12 cycles
						if (IDX = 4) then
							STATE <= CONF_A;
							IDX := 0;
						else						
							STATE <= INIT_A;
						end if;
					end if;

				when CONF_A =>
					DISPLAY_READY <= '0';
					ENABLE <= '1';
					if (TIME_RESET = '1') then
						if UPPER = '1' then 
							IDX := IDX + 1;
						end if;
						TIME_COUNT_LIMIT <= TIME_CONFIG; -- wait 40us for config
						STATE <= CONF_B;
					end if;
					
				when CONF_B =>
					DISPLAY_READY <= '0';
					ENABLE <= '0';
					if UPPER = '1' then
						if IDX = 4 then -- write msg
							DATA_REG <= "0010";
						else 
							DATA_REG <= CONFIG_UPPER(IDX);
						end if;
					else 
						DATA_REG <= CONFIG_LOWER(IDX);
					end if;
					
					if (TIME_RESET = '1') then
						UPPER <= not UPPER;
						if (IDX = 4) then
							STATE <= WAIT_CLEAR;
							TIME_COUNT_LIMIT <= TIME_CLEAR; -- wait 1640us for clear
							IDX := 0;
						else
							STATE <= CONF_A;
							TIME_COUNT_LIMIT <= TIME_ENABLE; -- wait 12 cycles
						end if;	
					end if;
					
				-- faz um clear entre config e write	
				when WAIT_CLEAR =>
					if (TIME_RESET = '1') then
						DISPLAY_READY <= '1';
						STATE <= WAIT_NEW_CMD;
					end if;
					
				-- espera aqui enquanto CPU nao envia uma nova instrucao
				when WAIT_NEW_CMD =>
					DISPLAY_READY <= '1';
					REG_SELECT <= '0';
					ENABLE <= '0';
					IDX := 0;
					
					-- decodificar pos_255 da ram pra bcd (linha 2 display)
					if BCD_DONE = '1' then
						DATA_UPPER(40) <= "0011";
						DATA_LOWER(40) <= BCD2;
						DATA_UPPER(41) <= "0011";
						DATA_LOWER(41) <= BCD1;
						DATA_UPPER(42) <= "0011";
						DATA_LOWER(42) <= BCD0;
					end if;
					
					if (NEW_IR_READY) = '1' then
						REG_SELECT <= '1';
						STATE <= WRITE_A;
						TIME_COUNT_LIMIT <= TIME_ENABLE;
					
						-- decodificar as strings (linha 1 display)
						-- ALU
						if DATA_IN(15 downto 12) = "0000" then -- add
							STR_LCD := str_add;
						
						elsif DATA_IN(15 downto 12) = "0001" then -- sub
							STR_LCD := str_sub;
							
						elsif DATA_IN(15 downto 12) = "0010" and DATA_IN(9 downto 8) = "00" then -- inc
							STR_LCD := str_inc;
							
						elsif DATA_IN(15 downto 12) = "0010" and DATA_IN(9 downto 8) = "01" then -- incc
							STR_LCD := str_incc;
							
						elsif DATA_IN(15 downto 12) = "0010" and DATA_IN(9 downto 8) = "10" then -- dec
							STR_LCD := str_dec;
						
						elsif DATA_IN(15 downto 12) = "0010" and DATA_IN(9 downto 8) = "11" then -- decc
							STR_LCD := str_decc;
							
						elsif DATA_IN(15 downto 12) = "0011" then -- and
							STR_LCD := str_and;
							
						elsif DATA_IN(15 downto 12) = "0100" then -- or
							STR_LCD := str_or;
							
						elsif DATA_IN(15 downto 12) = "0101" then -- not
							STR_LCD := str_not;
						
						elsif DATA_IN(15 downto 12) = "0110" then -- xor
							STR_LCD := str_xor;
							
						elsif DATA_IN(15 downto 12) = "0111" and DATA_IN(9 downto 8) = "00" then -- rol
							STR_LCD := str_rol;
							
						elsif DATA_IN(15 downto 12) = "0111" and DATA_IN(9 downto 8) = "01" then -- ror
							STR_LCD := str_ror;
							
						elsif DATA_IN(15 downto 12) = "0111" and DATA_IN(9 downto 8) = "10" then -- lsl
							STR_LCD := str_lsl;
						
						elsif DATA_IN(15 downto 12) = "0111" and DATA_IN(9 downto 8) = "11" then -- lsr
							STR_LCD := str_lsr;
						
						-- MEMORY
						elsif DATA_IN(15 downto 12) = "1000" and DATA_IN(9 downto 8) = "00" then -- push
							STR_LCD := str_push;
						
						elsif DATA_IN(15 downto 12) = "1000" and DATA_IN(9 downto 8) = "01" then -- pop
							STR_LCD := str_pop;
							
						elsif DATA_IN(15 downto 12) = "1000" and DATA_IN(9 downto 8) = "11" then -- ld
							STR_LCD := str_ld;
							
						elsif DATA_IN(15 downto 12) = "1001" then -- ldr
							STR_LCD := str_ldr;
							
						elsif DATA_IN(15 downto 12) = "1010" then -- str
							STR_LCD := str_str;
							
						-- JUMPS
						elsif DATA_IN(15 downto 12) = "1011" and DATA_IN(9 downto 8) = "00" then -- jmp
							STR_LCD := str_jmp;
							
						elsif DATA_IN(15 downto 12) = "1011" and DATA_IN(9 downto 8) = "01" then -- jmpr
							STR_LCD := str_jmpr;
							
						elsif DATA_IN(15 downto 12) = "1011" and DATA_IN(9 downto 8) = "10" then -- bz
							STR_LCD := str_bz;
							
						elsif DATA_IN(15 downto 12) = "1011" and DATA_IN(9 downto 8) = "11" then -- bnz
							STR_LCD := str_bnz;
							
						elsif DATA_IN(15 downto 12) = "1100" and DATA_IN(9 downto 8) = "00" then -- bcs
							STR_LCD := str_bcs;
							
						elsif DATA_IN(15 downto 12) = "1100" and DATA_IN(9 downto 8) = "01" then -- bcc
							STR_LCD := str_bcc;
							
						elsif DATA_IN(15 downto 12) = "1100" and DATA_IN(9 downto 8) = "10" then -- beq
							STR_LCD := str_beq;
							
						elsif DATA_IN(15 downto 12) = "1100" and DATA_IN(9 downto 8) = "11" then -- bneq
							STR_LCD := str_bneq;
							
						elsif DATA_IN(15 downto 12) = "1101" and DATA_IN(9 downto 8) = "00" then -- bgt
							STR_LCD := str_bgt;
							
						elsif DATA_IN(15 downto 12) = "1101" and DATA_IN(9 downto 8) = "01" then -- bgez
							STR_LCD := str_bgez;
							
						elsif DATA_IN(15 downto 12) = "1101" and DATA_IN(9 downto 8) = "10" then -- blt
							STR_LCD := str_blt;
							
						elsif DATA_IN(15 downto 12) = "1101" and DATA_IN(9 downto 8) = "11" then -- blez
							STR_LCD := str_blez;
							
						elsif DATA_IN(15 downto 12) = "1111" then
							STR_LCD := str_halt;
						end if;	

						for i in 0 to 11 loop
							DATA_UPPER(i+1) <= STR_LCD(7+(8*i) downto 4+(8*i)); -- 7 downto 4; 15 downto 12; 23 donwto 20; .....
							DATA_LOWER(i+1) <= STR_LCD(3+(8*i) downto (8*i));   -- 3 downto 0; 11 downto 8; 19 downto 16; ......
						end loop;
						
					end if;

				when WRITE_A =>
					DISPLAY_READY <= '0';
					REG_SELECT <= '1';
					ENABLE <= '1';
					if (TIME_RESET = '1') then
						if UPPER = '1' then 
							IDX := IDX + 1;
						end if;
						TIME_COUNT_LIMIT <= TIME_WAIT; -- wait 40us for msg
						STATE <= WRITE_B;
					end if;

				when WRITE_B =>
					DISPLAY_READY <= '0';
					REG_SELECT <= '1';
					ENABLE <= '0';
					if UPPER = '1' then
						if (IDX = 80) then -- terminou mensagem
							DATA_REG <= "0010";
						else 
							DATA_REG <= DATA_UPPER(IDX);
						end if;
					else
						DATA_REG <= DATA_LOWER(IDX);
					end if;
					
					if (TIME_RESET = '1') then
						UPPER <= not UPPER;
						TIME_COUNT_LIMIT <= TIME_ENABLE;
						if (IDX = 80) then -- terminou mensagem
							STATE <=  WAIT_NEW_CMD;
							IDX := 0;
						else
							STATE <= WRITE_A;
						end if;
					end if;

				when others =>
					STATE <= IDLE;
			end case;
		end if;
	end process;

	BCD_START   <= BCD_READY or NEW_IR_READY;
	DATA 		   <= DATA_REG;
	LCD_RS 		<= REG_SELECT;
	LCD_E 		<= ENABLE;
	SF 			<= '1';
	LCD_RW 		<= '0';
	TIME_RESET 	<= '1' when TIME_COUNT = TIME_COUNT_LIMIT else '0';
	
end Behavioral;

