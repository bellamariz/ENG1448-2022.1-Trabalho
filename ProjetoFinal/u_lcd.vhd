library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity u_lcd is
	port(
		CLK 						: in STD_LOGIC;
		RESET						: in STD_LOGIC;
		UPDATE_LCD					: in STD_LOGIC;
		DATA_IN						: in STD_LOGIC_VECTOR(15 downto 0); -- IR & POS 255 
		DATA 						: out STD_LOGIC_VECTOR(3 downto 0);
		LCD_E, LCD_RS, LCD_RW 	    : out STD_LOGIC;
		SF 							: out STD_LOGIC
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
	signal START : STD_LOGIC;
	signal READY : STD_LOGIC;
	signal DONE_TICK : STD_LOGIC;


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
	-- tempo para enviar os proximos 4 bits da nossa mensagem (1 us / 20 ns) = 50
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
	
begin

	bcd : entity work.u_bcd(Behavioral)
		port map (
			CLK			=> CLK,
			RESET		=> RESET,
			START 		=> START,
			BIN 		=> DATA_IN(7 downto 0),
			BCD2 		=> BCD2, 
			BCD1		=> BCD1,	
			BCD0		=> BCD0,	
			READY 		=> READY,
			DONE_TICK 	=> DONE_TICK
		);
	
	
	process(CLK)
	begin
		if rising_edge(CLK) then
			if (TIME_RESET = '1') then
				TIME_COUNT <= (others => '0');
			else
				TIME_COUNT <= STD_LOGIC_VECTOR( unsigned(TIME_COUNT) + 1 );
			end if;
		end if;
	end process;
	
	maq_estado : process(CLK)
		variable IDX : natural;
		variable str_LCD : STD_LOGIC_VECTOR(95 downto 0);
	begin
		if rising_edge(CLK) then
			case STATE is
				when IDLE =>
					REG_SELECT <= '0';
					ENABLE <= '0';
					IDX := 0;
					TIME_COUNT_LIMIT <= TIME_READY;
					DATA_REG <= "0011"; -- irei para INIT_A --> data = 3h
					if (TIME_RESET = '1') then
						STATE <= INIT_A;
						TIME_COUNT_LIMIT <= TIME_ENABLE; -- wait 12 cycles
					end if;
					
				when INIT_A =>
					ENABLE <= '1';
					if (TIME_RESET = '1') then 
						TIME_COUNT_LIMIT <= TIME_DATA(IDX);
						IDX := IDX + 1;
						STATE <= INIT_B;
					end if;
					
				when INIT_B =>
					ENABLE <= '0';
					if (IDX < 3) then
						DATA_REG <= "0011"; -- data = 3h
					elsif (IDX = 3) then
						DATA_REG <= "0010"; -- data = 2h
					else -- irei para CONF_A 
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
					ENABLE <= '1';
					if (TIME_RESET = '1') then
						if UPPER = '1' then 
							IDX := IDX + 1;
						end if;
						TIME_COUNT_LIMIT <= TIME_CONFIG; -- wait 40us for config
						STATE <= CONF_B;
					end if;
					
				when CONF_B =>
					ENABLE <= '0';
					if UPPER = '1' then
						DATA_REG <= CONFIG_UPPER(IDX);
--						if IDX = 4 then -- write msg
--							DATA_REG <= DATA_UPPER(0);
--						else 
--							DATA_REG <= CONFIG_UPPER(IDX);
--						end if;
					else 
						DATA_REG <= CONFIG_LOWER(IDX);
					end if;
					
					if (TIME_RESET = '1') then
						UPPER <= not UPPER;
						if (IDX = 4) then
							-- LCD_READY <= '1';
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
						STATE <= WAIT_NEW_CMD;
					end if;
				
				-- espera aqui enquanto CPU nao envia uma nova instrucao
				when WAIT_NEW_CMD =>
					REG_SELECT <= '0';
					ENABLE <= '0';
					IDX := 0;
					
					-- CPU enviou nova instrucao pra LCD exibir
					if (UPDATE_LCD) = '1' then
						REG_SELECT <= '1';
						STATE <= WRITE_A;
						TIME_COUNT_LIMIT <= TIME_ENABLE;
						
						--TODO: terminar de decodificar as strings
						if DATA_IN(15 downto 12) = "0000" then -- add
							str_LCD := str_add;
						
						elsif DATA_IN(15 downto 12) = "0001" then -- sub
							str_LCD := str_sub;
							
						elsif DATA_IN(15 downto 12) = "1000" and DATA_IN(9 downto 8) = "11" then -- ld
							str_LCD := str_ld;
							
						elsif DATA_IN(15 downto 12) = "1010" then -- str
							str_LCD := str_str;
						end if;	

						for i in 0 to 11 loop
							DATA_UPPER(i) <= str_LCD(95-(8*i) downto 92-(8*i)); --95 downto 92; 87 downto 84; 79 downto 76; .....; 7 downto 4 -- 4 primeiros
							DATA_LOWER(i) <= str_LCD(91-(8*i) downto 88-(8*i)); --91 downto 88; 83 downto 80; 75 donwto 72; .....; 3 downto 0 -- 4 ultimos
						end loop;
		
						DATA_UPPER(40) <= "0011";
						DATA_LOWER(40) <= BCD2;
						DATA_UPPER(41) <= "0011";
						DATA_LOWER(41) <= BCD1;
						DATA_UPPER(42) <= "0011";
						DATA_LOWER(42) <= BCD0;
						
					end if;


				when WRITE_A =>
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
					REG_SELECT <= '1';
					ENABLE <= '0';
					if UPPER = '1' then
						DATA_REG <= DATA_UPPER(IDX);
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

	DATA 		<= DATA_REG;
	LCD_RS 		<= REG_SELECT;
	LCD_E 		<= ENABLE;
	SF 			<= '1';
	LCD_RW 		<= '0';
	TIME_RESET 		<= '1' when TIME_COUNT = TIME_COUNT_LIMIT else '0';
	
end Behavioral;

