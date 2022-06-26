library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity u_lcd is
	port(
		CLK 							: in STD_LOGIC;
		-- TODO: colocar entrada aqui dos dados vindos da cpu
		DATA 							: out STD_LOGIC_VECTOR (3 downto 0);
		LCD_E, LCD_RS, LCD_RW 	: out STD_LOGIC;
		SF 							: out STD_LOGIC
	);

end u_lcd;

architecture Behavioral of u_lcd is

	type time_data_t is array (0 to 3) of STD_LOGIC_VECTOR(19 downto 0);
	signal time_data : time_data_t := (
		0 => STD_LOGIC_VECTOR(TO_UNSIGNED(205000, 20)), 
		1 => STD_LOGIC_VECTOR(TO_UNSIGNED(5000, 20)), 
		2 => STD_LOGIC_VECTOR(TO_UNSIGNED(2000, 20)), 
		3 => STD_LOGIC_VECTOR(TO_UNSIGNED(2000, 20)) 
	);
	
	type fsm_t is (idle, init_a, init_b, conf_a, conf_b, wait_clear, write_a, write_b, finish);
	signal state : fsm_t := idle;
	
	-- tempo de espera para a inicializacao (passo 0)
	constant time_ready : STD_LOGIC_VECTOR(19 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(750000, 20));
	-- tempo para enviar os proximos 4 bits da nossa mensagem (1 us / 20 ns) = 50
	constant time_wait : STD_LOGIC_VECTOR(19 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(2000, 20));
	-- tempo para enviar comando de configuracao (40us / 20ns) = 2000
	constant time_config : STD_LOGIC_VECTOR(19 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(2000, 20));
	-- tempo para enviar comando de clear (1640us / 20ns) = 82000
	constant time_clear : STD_LOGIC_VECTOR(19 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(82000, 20));
	-- tempo para esperar o enable virar '1'
	constant time_enable : STD_LOGIC_VECTOR(19 downto 0) := STD_LOGIC_VECTOR(TO_UNSIGNED(12, 20));
	
	signal data_reg : STD_LOGIC_VECTOR (3 downto 0) := (others => '0');
	signal enable  : STD_LOGIC := '0';
	signal reg_select : STD_LOGIC := '0';
	signal reset : STD_LOGIC := '0';
	signal upper : STD_LOGIC := '0';
	
	signal time_count : STD_LOGIC_VECTOR (19 downto 0) := (others => '0');
	signal time_count_limit : STD_LOGIC_VECTOR (19 downto 0) := (others => '1');
	
	type msg_t is array (0 to 9) of STD_LOGIC_VECTOR(3 downto 0);
	signal data_upper : msg_t := (
		0 => "0100", 
		1 => "0110", 
		2 => "0110", 
		3 => "0110", 
		4 => "0110", 
		5 => "0111", 
		6 => "0010", 
		7 => "0100", 
		8 => "0010", 
		9 => "0101"  
	);
	signal data_lower : msg_t := (
		0 => "0010", 
		1 => "0101", 
		2 => "1001",  
		3 => "1010",  
		4 => "1111",  
		5 => "0011",  
		6 => "0000", 
		7 => "1001", 
		8 => "0110", 
		9 => "0010" 
	);
	
	type config_t is array (0 to 3) of STD_LOGIC_VECTOR(3 downto 0);
	signal config_upper : config_t := (
		0 => "0010", -- 2 --> function set
		1 => "0000", -- 0 --> entry mode set
		2 => "0000", -- 0 --> display on/off
		3 => "0000" -- 0 --> clear
	);
	signal config_lower : config_t := (
		0 => "1000", -- 8
		1 => "0110", -- 6
		2 => "1100", -- C 
		3 => "0001" -- 1 
	); 
	
begin
	
	process(CLK)
	begin
		if rising_edge(CLK) then
			if (reset = '1') then
				time_count <= (others => '0');
			else
				time_count <= STD_LOGIC_VECTOR( unsigned(time_count) + 1 );
			end if;
		end if;
	end process;
	
	maq_estado : process(CLK)
		variable idx : natural;
	begin
		if rising_edge(CLK) then
			case state is
				when idle =>
					reg_select <= '0';
					enable <= '0';
					idx := 0;
					time_count_limit <= time_ready;
					data_reg <= "0011"; -- irei para init_a --> data = 3h
					if (reset = '1') then
						state <= init_a;
						time_count_limit <= time_enable; -- wait 12 cycles
					end if;
					
				when init_a =>
					enable <= '1';
					if (reset = '1') then 
						time_count_limit <= time_data(idx);
						idx := idx + 1;
						state <= init_b;
					end if;
					
				when init_b =>
					enable <= '0';
					if (idx < 3) then
						data_reg <= "0011"; -- data = 3h
					elsif (idx = 3) then
						data_reg <= "0010"; -- data = 2h
					else -- irei para conf_a 
						data_reg <= "0010"; -- data = 2h (0x28)
					end if;
					
					if (reset = '1') then
						time_count_limit <= time_enable; -- wait 12 cycles
						if (idx = 4) then
							state <= conf_a;
							idx := 0;
						else						
							state <= init_a;
						end if;
					end if;

				when conf_a =>
					enable <= '1';
					if (reset = '1') then
						if upper = '1' then 
							idx := idx + 1;
						end if;
						time_count_limit <= time_config; -- wait 40us for config
						state <= conf_b;
					end if;
					
				when conf_b =>
					enable <= '0';
					if upper = '1' then
						if idx = 4 then -- write msg
							data_reg <= data_upper(0);
						else 
							data_reg <= config_upper(idx);
						end if;
					else 
						data_reg <= config_lower(idx);
					end if;
					
					if (reset = '1') then
						upper <= not upper;
						if (idx = 4) then -- irei para write_a
							state <= wait_clear;
							time_count_limit <= time_clear; -- wait 1640us for clear
							idx := 0;
						else
							state <= conf_a;
							time_count_limit <= time_enable; -- wait 12 cycles
						end if;	
					end if;
					
				when wait_clear =>
					reg_select <= '1';
					if (reset = '1') then
						state <= write_a;
						time_count_limit <= time_enable;
					end if;

				when write_a =>
					reg_select <= '1';
					enable <= '1';
					if (reset = '1') then
						if upper = '1' then 
							idx := idx + 1;
						end if;
						time_count_limit <= time_wait; -- wait 40us for msg
						state <= write_b;
					end if;

				when write_b =>
					reg_select <= '1';
					enable <= '0';
					if upper = '1' then
						if (idx = 10) then -- clear
							data_reg <= config_upper(3);
						else 
							data_reg <= data_upper(idx);
						end if;
					else
						data_reg <= data_lower(idx);
					end if;
					
					if (reset = '1') then
						upper <= not upper;
						time_count_limit <= time_enable;
						if (idx = 10) then -- terminou mensagem
							state <= finish;
							idx := 0;
						else
							state <= write_a;
						end if;
					end if;
					
				when finish =>
					reg_select <= '0';
					enable <= '0';

				when others =>
					state <= idle;
			end case;
		end if;
	end process;

	DATA <= data_reg;
	LCD_RS <= reg_select;
	LCD_E <= enable;
	SF <= '1';
	LCD_RW <= '0';
	RESET <= '1' when time_count = time_count_limit else '0';

end Behavioral;

