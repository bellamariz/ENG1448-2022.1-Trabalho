library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity main is
	port(
		draft : in STD_LOGIC;
		draft2 : in STD_LOGIC;
		draft3 : in STD_LOGIC
	);
end main;

architecture Behavioral of main is

begin

	cpu : entity work.u_cpu(Behavioral)
		port map (
			draft => draft
		);
		
	lcd : entity work.u_lcd(Behavioral)
		port map (
			draft => draft1
		);
		
	memory : entity work.u_ram(rtl)
		port map (
			draft => draft2
		);

end Behavioral;

