library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity main is
	generic( clk_slow_counter  : natural := 12_500_000 ); -- 50000000
	port(
		CLK 							: in  STD_LOGIC;
		RESET							: in  STD_LOGIC;
		LCD_E, LCD_RS, LCD_RW 	        : out STD_LOGIC;
		SF_CE0 						    : out STD_LOGIC;
		LEDS							: out STD_LOGIC_VECTOR(7 downto 0);
		DOUT_LCD						: out STD_LOGIC_VECTOR(3 downto 0)
	);
end main;

architecture Behavioral of main is

	-- fios para a RAM e CPU
	signal POS_255 	    : STD_LOGIC_VECTOR(7 downto 0);
	signal DOUT_RAM 	: STD_LOGIC_VECTOR(7 downto 0);
	signal DIN_LCD		: STD_LOGIC_VECTOR(15 downto 0);
	signal DIN_RAM 	    : STD_LOGIC_VECTOR(7 downto 0);
   signal ADDR 		: STD_LOGIC_VECTOR(7 downto 0);
   signal IR 		: STD_LOGIC_VECTOR(7 downto 0);
	signal WE 			: STD_LOGIC;
	
	-- sinais de controle
	signal CLK_SLOW	     		 : STD_LOGIC := '0';
	signal NEW_IR_READY  		 : STD_LOGIC := '0';
	signal DISPLAY_READY 		 : STD_LOGIC := '0';
	signal NEW_IR   	 		 : STD_LOGIC := '0';
	signal NEW_IR_REG    		 : STD_LOGIC := '0';

begin

	DIN_LCD <= IR & POS_255;
	NEW_IR_READY  <= NEW_IR and not(NEW_IR_REG);

	-- processo para slow down o clock da CPU
	counter_div_tempo : process(CLK, RESET)
		variable COUNTER : unsigned(27 downto 0) := (others => '0');
	begin
		if (RESET = '1') then
			COUNTER := (others => '0');
			CLK_SLOW <= '0';
		elsif rising_edge(clk) then
			if COUNTER = clk_slow_counter then
				COUNTER := (others => '0');
				CLK_SLOW <= not CLK_SLOW;
			else
				COUNTER := COUNTER + 1;
			end if;
		end if;
	end process;
	
	
	-- processo para fazer o tick: avisar lcd pra exibir nova instrucao
	new_instruction : process(CLK)
	begin
		if rising_edge(CLK) then
			NEW_IR_REG <= NEW_IR;
		end if;
	end process;
	
	
	-- modulos importados
	cpu : entity work.u_cpu(Behavioral)
		port map (
			CLK 			=> CLK_SLOW, 		
			RESET			=> RESET,
			DISPLAY_READY	=> DISPLAY_READY,
			DOUT    		=> DOUT_RAM,
			POS_255 		=> POS_255, 	
			DIN     		=> DIN_RAM,     	
			ADDR    		=> ADDR,    	
			WE 			=> WE, 		
			LEDS			=> LEDS,
			NEW_IR_READY	=> NEW_IR,
			IR_OUT		=> IR
		);

	memory : entity work.u_ram(rtl)
		port map (
			CLK     		=> CLK_SLOW,
			RESET			=> RESET,
			DIN     		=> DIN_RAM,    
			ADDR    		=> ADDR,   
			WE      		=> WE,     
			DOUT    		=> DOUT_RAM,   
			POS_255 		=> POS_255
		);
		
	lcd : entity work.u_lcd(Behavioral)
		port map (
			CLK 			=>  CLK, 								
			RESET			=>	RESET,
			NEW_IR_READY  	=>  NEW_IR_READY,
			DATA_IN			=>	DIN_LCD,			
			DATA 			=>	DOUT_LCD, 				
			LCD_E       	=>  LCD_E, 
			LCD_RS      	=>  LCD_RS,
			LCD_RW      	=>  LCD_RW,
			SF 				=>	SF_CE0,
			DISPLAY_READY	=>  DISPLAY_READY
		);
		

end Behavioral;

