library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- All needed inputs and outputs on the board
entity cpu is port(
		RESET			:	in		std_logic;
		CLK			:	in		std_logic;
		KEY			:	in 	std_logic;
		
		COUT			:	out	std_logic;
		HEX0			:	out	std_logic_vector(6 downto 0);
		HEX1			:	out	std_logic_vector(6 downto 0);
		HEX2			:	out	std_logic_vector(6 downto 0);
		HEX3			:	out	std_logic_vector(6 downto 0);
		HEX4			:	out	std_logic_vector(6 downto 0);
		HEX5			:	out	std_logic_vector(6 downto 0)
		
		);
end cpu;

architecture behavior of cpu is
	
	-- All states neeeded, and defining current state and next state
	type state is (S_RESET, S_FETCH, S_DECODE, S_EXECUTE1, S_FETCH_DATA, S_EXECUTE2);
	signal current_state : state; 
	signal next_state : state;
	
	-- 
	signal IR_LD	:	std_logic := '0';
	signal IR		: 	std_logic_vector(4 downto 0);
	signal PC_INC	:	std_logic := '0';
	signal PC_LD	:	std_logic := '0';
	signal PC		:  unsigned(7 downto 0) := (others => '0');
	
	-- Data paths
	signal INPUT	:	std_logic_vector(7 downto 0);
	signal MSA		:	std_logic_vector(1 downto 0) := "01";
	signal MSB		:	std_logic_vector(1 downto 0) := "10";
	signal MSC		: 	std_logic_vector(3 downto 0) := "0000";
	signal REGA		:	std_logic_vector(7 downto 0);
	signal REGB		:	std_logic_vector(7 downto 0);
	signal OUTPUT	:	std_logic_vector(7 downto 0);
	signal REGA_LD	:	std_logic := '0';
	signal REGB_LD	:	std_logic := '0';
	
	-- ALU 
	signal A_next	:	std_logic_vector(7 downto 0);
	signal B_next	:	std_logic_vector(7 downto 0);
	signal A_unsigned: unsigned(7 downto 0);
	signal B_unsigned: unsigned(7 downto 0);
	signal MULT		: 	unsigned(15 downto 0);
	signal SUM		:	unsigned(8 downto 0);
	signal SUM_NO_CARRY		: 	unsigned(8 downto 0);
	signal CIN		:	std_logic := '0';
	signal COUT_r	:	std_logic := '0';
	
	-- Clock debouncer 
	signal PULSE	: 	std_logic;
	
	-- ROM
	component ROM is
		port(
			address	:	in std_logic_vector(7 downto 0);
			clock		:	in std_logic;
			q			:	out std_logic_vector(7 downto 0)
		);
	end component;
	
begin

	-- Making ROM
	ROM_MAKE	:	ROM
		port map(
			address	=>	std_logic_vector(PC),
			clock		=> CLK,
			q			=>	INPUT
		);

	with MSA select
		A_next <= INPUT	when "00",
					 REGA		when "01",
					 REGB		when "10",
					 OUTPUT	when "11";
					 
	with MSB select
		B_next <= INPUT	when "00",
					 REGA		when "01",
					 REGB		when "10",
					 OUTPUT	when "11";
		
	SUM <= ('0' & unsigned(REGA)) + ('0' & unsigned(REGB)) + unsigned(std_logic_vector(to_unsigned(0,7)) & CIN);
	SUM_NO_CARRY <= ('0' & unsigned(REGA)) + ('0' & unsigned(REGB)) + unsigned(std_logic_vector(to_unsigned(0,7)));
	A_unsigned <= unsigned(REGA);
   B_unsigned <= unsigned(REGB);
	MULT <= A_unsigned * B_unsigned;
	
	process(REGA, REGB, MSC, SUM, CIN)
	begin
	
		-- REGA Bus to OUTPUT Bus
		if (MSC = "0000") then
			OUTPUT <= REGA;
		
		-- REGB Bus to OUTPUT Bus
		elsif (MSC = "0001") then
			OUTPUT <= REGB;
			
		-- Complement of REGA Bus to OUTPUT Bus
		elsif (MSC = "0010") then
			OUTPUT <= not REGA;
			
		-- Bit wise AND REGA/REGB Bus to OUTPUT Bus
		elsif (MSC = "0011") then
			OUTPUT <= REGA and REGB;
		
		-- Bit wise OR REGA/REGB Bus to OUTPUT Bus
		elsif (MSC = "0100") then
			OUTPUT <= REGA or REGB;
			
		-- Unisgned sum of REGA Bus & REGB Bus to OUTPUT Bus
		elsif (MSC = "0101") then
			OUTPUT <= std_logic_vector(SUM(7 downto 0));
		
		-- Right Logical shift REGA by one bit to OUTPUT Bus
		elsif (MSC = "0110") then
			OUTPUT(0) <= REGA(1);
			OUTPUT(1) <= REGA(2);
			OUTPUT(2) <= REGA(3);
			OUTPUT(3) <= REGA(4);
			OUTPUT(4) <= REGA(5);
			OUTPUT(5) <= REGA(6);
			OUTPUT(6) <= REGA(7);
			OUTPUT(7) <= '0';
		
		-- Right Artithmetic shift REGA by one bit to OUTPUT Bus
		elsif (MSC = "0111") then
			OUTPUT(0) <= REGA(1);
			OUTPUT(1) <= REGA(2);
			OUTPUT(2) <= REGA(3);
			OUTPUT(3) <= REGA(4);
			OUTPUT(4) <= REGA(5);
			OUTPUT(5) <= REGA(6);
			OUTPUT(6) <= REGA(7);
			OUTPUT(7) <= REGA(7);
					
		-- Unsigned sum of REGA Bus & REGB Bus to OUTPUT Bus without Carry	
		elsif (MSC = "1000") then
			OUTPUT <= std_logic_vector(SUM_NO_CARRY(7 downto 0));
			
		-- Multiply REGA and REGB
		elsif (MSC = "1001") then
			OUTPUT <= std_logic_vector(MULT(7 downto 0));
			
		--	Increment REGA
		elsif (MSC = "1010") then
			OUTPUT <= std_logic_vector(unsigned(REGA) + 1);
			
		-- Left Logical Shift REGA Register by one bit
		elsif (MSC = "1011") then
			OUTPUT(0) <= '0';
			OUTPUT(1) <= REGA(0);
			OUTPUT(2) <= REGA(1);
			OUTPUT(3) <= REGA(2);
			OUTPUT(4) <= REGA(3);
			OUTPUT(5) <= REGA(4);
			OUTPUT(6) <= REGA(5);
			OUTPUT(7) <= REGA(6);
			
		-- Two's complement sum of REGA Bus & REGB Bus to OUTPUT Bus with Cin
		elsif (MSC = "1100") then
			OUTPUT <= std_logic_vector(SUM(7 downto 0));
				
		-- Two's complement sum of REGA Bus & REGB Bus to OUTPUT Bus
		elsif (MSC = "1101") then
			OUTPUT <= std_logic_vector(SUM_NO_CARRY(7 downto 0));
			
		-- Left Rotate with Carry REGA by one bit to OUTPUT Bus
		elsif (MSC = "1110") then
			OUTPUT(0) <= REGA(1);
			OUTPUT(1) <= REGA(2);
			OUTPUT(2) <= REGA(3);
			OUTPUT(3) <= REGA(4);
			OUTPUT(4) <= REGA(5);
			OUTPUT(5) <= REGA(6);
			OUTPUT(6) <= REGA(7);
			OUTPUT(7) <= REGA(0);
			
		-- Left Arithmetic shift REGA by one bit to OUTPUT Bus
		elsif (MSC = "1111") then
			OUTPUT(0) <= '0';
			OUTPUT(1) <= REGA(0);
			OUTPUT(2) <= REGA(1);
			OUTPUT(3) <= REGA(2);
			OUTPUT(4) <= REGA(3);
			OUTPUT(5) <= REGA(4);
			OUTPUT(6) <= REGA(5);
			OUTPUT(7) <= REGA(6);
		
		end if;
	
	end process;
	
	-- Flow between states (If current is something, what should next be, with IR condition of course)
	process(current_state, IR)
	begin
		next_state <= current_state;
		
		if (current_state = S_RESET) then
			next_state <= S_FETCH;
		
		elsif (current_state = S_FETCH) then
			next_state <= S_DECODE;
		
		elsif (current_state = S_DECODE) then
			if (IR = "00001" OR IR = "00101" OR IR = "00110" OR IR = "00111" OR IR = "01000" OR IR = "01001" OR IR = "10000") then
				next_state <= S_FETCH_DATA;
			else
				next_state <= S_EXECUTE1;
			end if;
		
		elsif (current_state = S_EXECUTE1) then
			next_state <= S_FETCH;
			
		elsif (current_state = S_FETCH_DATA) then
			next_state <= S_EXECUTE2;
			
		elsif (current_state = S_EXECUTE2) then
			next_state <= S_FETCH;
		
		end if;
	end process;
	
	-- What should happen inside each state
	process(current_state, IR)
	begin
		IR_LD   <= '0';
		PC_INC  <= '0';
		PC_LD   <= '0';
		REGA_LD <= '0';
		REGB_LD <= '0';
		MSA     <= "01";
		MSB     <= "10";
		MSC     <= "0000";
		if (current_state = S_RESET) then
			
		elsif (current_state = S_FETCH) then
			IR_LD <= '1';
			
		elsif (current_state = S_DECODE) then
			PC_INC <= '1';
			
		elsif (current_state = S_EXECUTE1) then
		
			-- TAB (Copy REGA to REGB)
			if (IR = "00000") then
				MSA <= "01";
				MSB <= "01";
				MSC <= "0000";
				REGB_LD <= '1';
			
			-- COMA (Bitwise complement REGA)
			elsif (IR = "00010") then
				MSA <= "11";
				MSB <= "10";
				MSC <= "0010";
				REGA_LD <= '1';
				
			-- ABAC (REGA = Unsigned sum of REGA & REGB with Carry)
			elsif (IR = "00011") then
				MSA <= "11";
				MSB <= "10";
				MSC <= "0101";
				REGA_LD <= '1';
			
			-- ABA (REGA = Unisgned sum of REGA & REGB without Carry)
			elsif (IR = "00100") then
				MSA <= "11";
				MSB <= "10";
				MSC <= "1000";
				REGA_LD <= '1';
	
			-- MULT (REGA <= REGA * REGB)
			elsif (IR = "01010") then
			  MSA <= "11";
			  MSB <= "10";
			  MSC <= "1001";
			  REGA_LD <= '1';
      
			-- INCA (REGA <= REGA + 1)
			elsif (IR = "01100") then
				MSA <= "11";
				MSB <= "10";
				MSC <= "1010";
				REGA_LD <= '1';
			
			-- SABA (Two's complement sum of REGA & REGB to REGA)
			elsif (IR = "01101") then
				MSA <= "11";
				MSB <= "10";
				MSC <= "1101";
				REGA_LD <= '1';
				
			-- SARA (Shift REGA register Artihmetic Right by 1 bit)
			elsif (IR = "01110") then
				MSA <= "11";
				MSB <= "10";
				MSC <= "0111";
				REGA_LD <= '1';
				
			-- SABAC (Two's complement sum of REGA & REGB & Cin to REGA)
			elsif (IR = "01111") then
				MSA <= "11";
				MSB <= "10";
				MSC <= "1100";
				REGA_LD <= '1';
			
			-- NOP
			else
				MSA <= "01";
				MSB <= "10";
				MSC <= "0000";
			end if;
			
		elsif (current_state = S_FETCH_DATA) then
			--PC_INC <= '1';
			
		elsif (current_state = S_EXECUTE2) then
			
			-- LDAA #data (Load REGA with input data)
			if (IR = "00001") then
				MSA <= "00";
				MSB <= "10";
				MSC <= "0000";
				REGA_LD <= '1';
			
			-- SLRA #data (Logical Shift REGA register Right by #data bits (1-7))
			elsif (IR = "00101") then
				MSA <= "11";
				MSB <= "10";
				MSC <= "0110";
				REGA_LD <= '1';
				
			-- SLLA #data (Logical Shift REGA register Left by #data bits (1-7))
			elsif (IR = "00110") then
				MSA <= "11";
				MSB <= "10";
				MSC <= "1111";
				REGA_LD <= '1';
			
			-- JMP Addr (Load PC with input address)
			elsif (IR = "00111") then
				PC_LD <= '1';
				
			-- JMPZ ADDR (Load PC with input address if REGA = 0)
			elsif (IR = "01000") then
				if (REGA = "00000000") then
					PC_LD <= '1';
				end if;
				
			-- JMPNEGA (Load PC with input address if REGA is negative)
			elsif (IR = "01001") then
				if (REGA(7) = '1') then
					PC_LD <= '1';
				end if;
			
			-- ROTL #data (Left Rotate with Carry REGA by #data bits (1-7))
			elsif (IR = "10000") then
				MSA <= "11";
				MSB <= "10";
				MSC <= "1110";
				REGA_LD <= '1';
			
			else
				null;
			end if;
        
      PC_INC <= '1';
		else
			null;
		end if;
	end process;
	
	-- If we hit reset, what exactly should happen
	process(CLK, RESET)
	begin
		if (RESET = '0') then
			current_state <= S_RESET;
			PC <= "00000000";
			REGA <= "00000000";
			REGB <= "00000000";
			IR <= "00000";
			COUT_r <= '0';
			
		elsif (rising_edge(CLK)) then
			if (PULSE = '1') then
				
				current_state <= next_state;
			
				if (IR_LD = '1') then
					IR <= INPUT(4 downto 0);
				end if;
			
				if (REGA_LD = '1') then
					REGA <= A_next;
				end if;
			
				if (REGB_LD = '1') then
					REGB <= B_next;
				end if;
				
				if (MSC = "0101") then
					COUT_r <= std_logic(SUM(8));
				end if;
				
				if (PC_LD = '1') then
					PC <= unsigned(INPUT);
					
				elsif (PC_INC = '1') then
					PC <= PC + 1;
				end if;
			end if;
		end if;
	end process;
	
	COUT <= COUT_r;
	
	debounce	 :	entity work.Debounce
		port map	(Clk => CLK, Key => KEY, pulse => PULSE);
	
	hex0_inst : entity work.sev_seg_vhdl
		port map (bin => OUTPUT(3 downto 0), seg => HEX0);
			
	hex1_inst : entity work.sev_seg_vhdl
		port map (bin => OUTPUT(7 downto 4), seg => HEX1);
	
	hex2_inst : entity work.sev_seg_vhdl
		port map (bin => REGB(3 downto 0), seg => HEX2);
			
	hex3_inst : entity work.sev_seg_vhdl
		port map (bin => REGB(7 downto 4), seg => HEX3);
	
	hex4_inst : entity work.sev_seg_vhdl
		port map (bin => REGA(3 downto 0), seg => HEX4);
			
	hex5_inst : entity work.sev_seg_vhdl
		port map (bin => REGA(7 downto 4), seg => HEX5);
end behavior;