library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity u_cpu is
	port (
		CLK 		  		: in 	STD_LOGIC;
		RESET		  		: in 	STD_LOGIC;
		DISPLAY_READY 	: in 	STD_LOGIC;
		DOUT    	  		: in 	STD_LOGIC_VECTOR(7 downto 0);
      POS_255 	  		: in 	STD_LOGIC_VECTOR(7 downto 0);
		DIN     	  		: out STD_LOGIC_VECTOR(7 downto 0);
      ADDR    	  		: out STD_LOGIC_VECTOR(7 downto 0);
		WE 		      : out	STD_LOGIC;
		LEDS		  		: out STD_LOGIC_VECTOR(7 downto 0);
		NEW_IR_READY  	: out	STD_LOGIC;
		MBR_OUT		  	: out STD_LOGIC_VECTOR(7 downto 0)
	);
end u_cpu;

architecture Behavioral of u_cpu is		
	
	-- definindo os registradores
	-- registradores da cpu
	signal IR : STD_LOGIC_VECTOR(7 downto 0) := x"00";
	signal PC : STD_LOGIC_VECTOR(7 downto 0) := x"00";
	signal MAR : STD_LOGIC_VECTOR(7 downto 0) := x"00";
	signal MBR : STD_LOGIC_VECTOR(7 downto 0) := "00000000";
	signal SP : STD_LOGIC_VECTOR(7 downto 0) := "11111110";
	
	-- registradores auxiliares
	signal RA : STD_LOGIC_VECTOR(7 downto 0) := x"00";
	signal RB : STD_LOGIC_VECTOR(7 downto 0) := x"00";
	signal RC : STD_LOGIC_VECTOR(7 downto 0) := x"00";
	signal RD : STD_LOGIC_VECTOR(7 downto 0) := x"00";
	
	-- FSM para as operacoes da cpu
	type FSM_CPU is (IDLE, FETCH, DECODE_1, DECODE_2, EXECUTE);
	signal STATE : FSM_CPU := IDLE;
	
	-- contador para slow down o clock da cpu
	-- quantos bits precisamos pro clock ser de 2 segundos? 20ns x 10^8 = 2s
	-- log2(10^8) = 26.57 = 27 bits
	--signal COUNTER : unsigned(27 downto 0) := (others => '0');

	-- ALU
	signal ALU_A     : STD_LOGIC_VECTOR(7 downto 0) := x"00";
	signal ALU_B     : STD_LOGIC_VECTOR(7 downto 0) := x"00";
	signal ALU_CMD   : STD_LOGIC_VECTOR(7 downto 0) := x"00";
	signal ALU_CIN   : STD_LOGIC := '0';
	signal ALU_COUT  : STD_LOGIC := '0';
	signal ALU_FLAGS : STD_LOGIC_VECTOR(4 downto 0) := x"0" & '0';
	signal ALU_S     : STD_LOGIC_VECTOR(7 downto 0) := x"00";


begin

	-- importar modulo da ALU
	alu : entity work.u_alu(Behavioral)
		port map (
			RESET	=> RESET,
			A 		=> ALU_A,
			B 		=> ALU_B,
			CMD 	=> ALU_CMD,
			C_in 	=> ALU_CIN,
			C_out => ALU_COUT,
			FLAGS => ALU_FLAGS,
			S 		=> ALU_S
		);
		

	
	-- maquina de estados do ciclo de instrucoes da cpu
	instruction_cycle : process(CLK, RESET)
	begin
		if (RESET = '1') then
			RA  		  <= x"00";
			RB  		  <= x"00";
			RC  		  <= x"00";
			RD  		  <= x"00";
			IR  	     <= x"00";
			PC  		  <= x"00";
			MAR 		  <= x"00";
			MBR 		  <= "00000000";
			SP  		  <= "11111110";
			STATE 	  <= IDLE;
			
		elsif rising_edge(CLK) then
			NEW_IR_READY <= '0';
			case STATE is
				when IDLE =>
					if DISPLAY_READY = '1' then
						STATE <= FETCH;
					end if;
					
				-- FETCH instruction from ram
				when FETCH =>
					--NEW_IR_READY <= '1';
					IR <= DOUT;
					STATE <= DECODE_1;
				
				-- DECODE fetched opcode
				when DECODE_1 =>
					
					-- POP operation
					if IR(7 downto 4) = "1000" and IR(1 downto 0) = "01" then
						MAR <= STD_LOGIC_VECTOR(unsigned(SP) + 1);
					
					-- LOAD operation
					elsif DOUT(7 downto 4) = "1000" and DOUT(1 downto 0) = "11" then
						MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
					
					-- LDR operation
					elsif IR(7 downto 4) = "1001" then
						if (IR(1 downto 0) = "00") then
							MAR <= RA;
						elsif (IR(1 downto 0) = "01") then
							MAR <= RB;
						elsif (IR(1 downto 0) = "10") then
							MAR <= RC;
						else
							MAR <= RD;
						end if;
						
					end if;
					
					STATE <= DECODE_2;

				-- DECODE fetched opcode 
				when DECODE_2 =>
					-- ALU operations
					if (IR(7) = '0') then
						if (IR(3 downto 2) = "00") then
							ALU_A <= RA;
						elsif (IR(3 downto 2) = "01") then
							ALU_A <= RB;
						elsif (IR(3 downto 2) = "10") then
							ALU_A <= RC;
						else
							ALU_A <= RD;
						end if;
						
						if (IR(1 downto 0) = "00") then
							ALU_B <= RA;
						elsif (IR(1 downto 0) = "01") then
							ALU_B <= RB;
						elsif (IR(1 downto 0) = "10") then
							ALU_B <= RC;
						else
							ALU_B <= RD;
						end if;
						
						ALU_CMD <= IR;
					
					
					-- Memory operations			
					-- PUSH Rx --> MEM[SP] <- Rx, pc <- pc + 1, sp <- sp - 1
					elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "00" then
						MAR <= SP;
						if (IR(3 downto 2) = "00") then
							DIN <= RA;
						elsif (IR(3 downto 2) = "01") then
							DIN <= RB;
						elsif (IR(3 downto 2) = "10") then
							DIN <= RC;
						else
							DIN <= RD;
						end if;
						
						WE <= '1';
						
					-- POP Rx --> Rx <- MEM[SP + 1], pc <- pc + 1, sp <- sp + 1
					elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "01" then
						if (IR(3 downto 2) = "00") then
							RA <= DOUT;
						elsif (IR(3 downto 2) = "01") then
							RB <= DOUT;
						elsif (IR(3 downto 2) = "10") then
							RC <= DOUT;
						else
							RD <= DOUT;
						end if;
						
						MBR <= DOUT;
					
					-- LD Rx, 0x-- --> Rx <- MEM[PC + 1], pc <- pc + 2
					elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "11" then
						if (IR(3 downto 2) = "00") then
							RA <= DOUT;
						elsif (IR(3 downto 2) = "01") then
							RB <= DOUT;
						elsif (IR(3 downto 2) = "10") then
							RC <= DOUT;
						else
							RD <= DOUT;
						end if;
						
						MBR <= DOUT;
						
					-- LDR Rx, [Ry] --> Rx <- MEM[Ry], pc <- pc + 1
					elsif IR(7 downto 4) = "1001" then
						if (IR(3 downto 2) = "00") then
							RA <= DOUT;
						elsif (IR(3 downto 2) = "01") then
							RB <= DOUT;
						elsif (IR(3 downto 2) = "10") then
							RC <= DOUT;
						else
							RD <= DOUT;
						end if;
						
						MBR <= DOUT;
					
					-- STR Rx, [Ry] --> MEM[Ry] <- Rx, pc <- pc + 1
					elsif IR(7 downto 4) = "1010" then
						if (IR(1 downto 0) = "00") then
							MAR <= RA;
						elsif (IR(1 downto 0) = "01") then
							MAR <= RB;
						elsif (IR(1 downto 0) = "10") then
							MAR <= RC;
						else
							MAR <= RD;
						end if;
						
						if (IR(3 downto 2) = "00") then
							DIN <= RA;
						elsif (IR(3 downto 2) = "01") then
							DIN <= RB;
						elsif (IR(3 downto 2) = "10") then
							DIN <= RC;
						else
							DIN <= RD;
						end if;
						
						WE <= '1';
						
					
					-- Jump operations
					
					-- JMP 0x-- --> pc <-- MEM[PC+1]
					elsif IR(7 downto 4) = "1011" and IR(1 downto 0) = "00" then
						MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
					
					-- JMPR Rx --> pc <-- Rx
					elsif IR(7 downto 4) = "1011" and IR(1 downto 0) = "01" then
						if (IR(3 downto 2) = "00") then
							MAR <= RA;
						elsif (IR(3 downto 2) = "01") then
							MAR <= RB;
						elsif (IR(3 downto 2) = "10") then
							MAR <= RC;
						else
							MAR <= RD;
						end if;
						
					-- BZ Rx --> if (zero) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1011" and IR(1 downto 0) = "10" then
						if ALU_FLAGS(1) = '1' then
							if (IR(3 downto 2) = "00") then
								MAR <= RA;
							elsif (IR(3 downto 2) = "01") then
								MAR <= RB;
							elsif (IR(3 downto 2) = "10") then
								MAR <= RC;
							else
								MAR <= RD;
							end if;
						else
							MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						end if;
						
					-- BNZ Rx --> if (not zero) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1011" and IR(1 downto 0) = "11" then
						if ALU_FLAGS(1) = '0' then
							if (IR(3 downto 2) = "00") then
								MAR <= RA;
							elsif (IR(3 downto 2) = "01") then
								MAR <= RB;
							elsif (IR(3 downto 2) = "10") then
								MAR <= RC;
							else
								MAR <= RD;
							end if;
						else
							MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						end if;
						
					-- BCS Rx --> if (carry) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1100" and IR(1 downto 0) = "00" then
						if ALU_FLAGS(0) = '1' then
							if (IR(3 downto 2) = "00") then
								MAR <= RA;
							elsif (IR(3 downto 2) = "01") then
								MAR <= RB;
							elsif (IR(3 downto 2) = "10") then
								MAR <= RC;
							else
								MAR <= RD;
							end if;
						else
							MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						end if;
						
					-- BCC Rx --> if (not carry) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1100" and IR(1 downto 0) = "01" then
						if ALU_FLAGS(0) = '0' then
							if (IR(3 downto 2) = "00") then
								MAR <= RA;
							elsif (IR(3 downto 2) = "01") then
								MAR <= RB;
							elsif (IR(3 downto 2) = "10") then
								MAR <= RC;
							else
								MAR <= RD;
							end if;
						else
							MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						end if;
						
					-- BEQ Rx --> if (equal) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1100" and IR(1 downto 0) = "10" then
						if ALU_FLAGS(4) = '1' then
							if (IR(3 downto 2) = "00") then
								MAR <= RA;
							elsif (IR(3 downto 2) = "01") then
								MAR <= RB;
							elsif (IR(3 downto 2) = "10") then
								MAR <= RC;
							else
								MAR <= RD;
							end if;
						else
							MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						end if;
						
					-- BNEQ Rx --> if (not equal) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1100" and IR(1 downto 0) = "11" then
						if ALU_FLAGS(4) = '0' then
							if (IR(3 downto 2) = "00") then
								MAR <= RA;
							elsif (IR(3 downto 2) = "01") then
								MAR <= RB;
							elsif (IR(3 downto 2) = "10") then
								MAR <= RC;
							else
								MAR <= RD;
							end if;
						else
							MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						end if;
						
					-- BGT Rx --> if (greater) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1101" and IR(1 downto 0) = "00" then
						if ALU_FLAGS(3) = '1' then
							if (IR(3 downto 2) = "00") then
								MAR <= RA;
							elsif (IR(3 downto 2) = "01") then
								MAR <= RB;
							elsif (IR(3 downto 2) = "10") then
								MAR <= RC;
							else
								MAR <= RD;
							end if;
						else
							MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						end if;
						
					-- BGEZ Rx --> if (greater and zero) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1101" and IR(1 downto 0) = "01" then
						if ALU_FLAGS(3) = '1' and ALU_FLAGS(1) = '1' then
							if (IR(3 downto 2) = "00") then
								MAR <= RA;
							elsif (IR(3 downto 2) = "01") then
								MAR <= RB;
							elsif (IR(3 downto 2) = "10") then
								MAR <= RC;
							else
								MAR <= RD;
							end if;
						else
							MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						end if;
						
					-- BLT Rx --> if (smaller) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1101" and IR(1 downto 0) = "10" then
						if ALU_FLAGS(2) = '1' then
							if (IR(3 downto 2) = "00") then
								MAR <= RA;
							elsif (IR(3 downto 2) = "01") then
								MAR <= RB;
							elsif (IR(3 downto 2) = "10") then
								MAR <= RC;
							else
								MAR <= RD;
							end if;
						else
							MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						end if;
					
					-- BLEZ Rx --> if (smaller and zero) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1101" and IR(1 downto 0) = "11" then
						if ALU_FLAGS(2) = '1' and ALU_FLAGS(1) = '1' then
							if (IR(3 downto 2) = "00") then
									MAR <= RA;
								elsif (IR(3 downto 2) = "01") then
									MAR <= RB;
								elsif (IR(3 downto 2) = "10") then
									MAR <= RC;
								else
									MAR <= RD;
								end if;
						else
							MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						end if;
						 
					end if;
					
					STATE <= EXECUTE;

				-- EXECUTE instruction
				when EXECUTE =>
					WE <= '0';
					NEW_IR_READY <= '1';
					
					-- ALU operations
					if (IR(7) = '0') then
						ALU_CIN <= ALU_COUT;
						
						if (IR(3 downto 2) = "00") then
							RA <= ALU_S;
						elsif (IR(3 downto 2) = "01") then
							RB <= ALU_S;
						elsif (IR(3 downto 2) = "10") then
							RC <= ALU_S;
						else
							RD <= ALU_S;
						end if;
						
						PC  <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						MBR <= ALU_S;
					
					-- Memory operations
					-- PUSH Rx --> MEM[SP] <- Rx, pc <- pc + 1, sp <- sp - 1
					elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "00" then
						SP  <= STD_LOGIC_VECTOR(unsigned(SP) - 1);
						PC  <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						
					-- POP Rx --> Rx <- MEM[SP + 1], pc <- pc + 1, sp <- sp + 1
					elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "01" then
						SP  <= STD_LOGIC_VECTOR(unsigned(SP) + 1);
						PC  <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						
					-- LOAD Rx, 0x-- --> Rx <- MEM[PC+1], pc <- pc + 2
					elsif IR(7 downto 4) = "1000" and IR(1 downto 0) = "11" then    
						PC  <= STD_LOGIC_VECTOR(unsigned(PC) + 2);
						MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 2);
						
					-- LDR Rx, [Ry] --> Rx <- MEM[Ry], pc <- pc + 1
					elsif IR(7 downto 4) = "1001" then
						PC  <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						
					-- STR Rx, [Ry] --> MEM[Ry] <- Rx, pc <- pc + 1
					elsif IR(7 downto 4) = "1010" then
						PC  <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
										
					
					-- Jump operations
					-- JMP 0x-- --> pc <-- MEM[PC+1]
					elsif IR(7 downto 4) = "1011" and IR(1 downto 0) = "00" then
						PC <= DOUT;
						MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						 
					-- JMPR Rx --> pc <-- Rx
					elsif IR(7 downto 4) = "1011" and IR(1 downto 0) = "01" then
						PC  <= MAR;
						MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						 
					-- BZ Rx --> if (zero) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1011" and IR(1 downto 0) = "10" then
						PC  <= MAR;
						--MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
					
					-- BNZ Rx --> if (not zero) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1011" and IR(1 downto 0) = "11" then
						PC  <= MAR;
						--MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						
					-- BCS Rx --> if (carry) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1100" and IR(1 downto 0) = "00" then
						PC  <= MAR;
						--MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						
					-- BCC Rx --> if (not carry) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1100" and IR(1 downto 0) = "01" then
						PC  <= MAR;
						--MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						
					-- BEQ Rx --> if (equal) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1100" and IR(1 downto 0) = "10" then
						PC  <= MAR;
						--MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						
					-- BNEQ Rx --> if (not equal) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1100" and IR(1 downto 0) = "11" then
						PC  <= MAR;
						--MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						
					-- BGT Rx --> if (greater) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1101" and IR(1 downto 0) = "00" then
						PC  <= MAR;
						--MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						
					-- BGEZ Rx --> if (greater and zero) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1101" and IR(1 downto 0) = "01" then
						PC  <= MAR;
						--MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						
					-- BLT Rx --> if (smaller) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1101" and IR(1 downto 0) = "10" then
						PC <= MAR;
						--MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
						
					-- BLEZ Rx --> if (smaller and zero) pc <-- Rx else pc <-- pc + 1
					elsif IR(7 downto 4) = "1101" and IR(1 downto 0) = "11" then
						PC <= MAR;
						--MAR <= STD_LOGIC_VECTOR(unsigned(PC) + 1);
					
					-- HALT pc <-- pc
					elsif IR(7 downto 4) = "1111" then
						PC <= PC;
						MAR <= PC;
					
					end if;

					STATE <= IDLE;
			end case;
		end if;
	end process;
	
	-- enderecamento
	ADDR <= MAR;
	
	-- saidas de LED para CLK e flags da ALU
	LEDS(7) <= CLK;
	LEDS(6 downto 5) <= "00";
	LEDS(4 downto 0) <= ALU_FLAGS;

end Behavioral;

