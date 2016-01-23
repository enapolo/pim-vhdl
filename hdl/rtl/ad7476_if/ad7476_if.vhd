-----------------------------------------------------------------------------
-- file			: ad7476_if.vhd 
--
-- brief		: adc7476 interface
-- author(s)	: marc at pignat dot org
-- license		: The MIT License (MIT) (http://opensource.org/licenses/MIT)
--				  Copyright (c) 2015 Marc Pignat
--
-- limitations	: uses a 2^prescaler clock (prescaler >= 1)
--
-----------------------------------------------------------------------------
library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity ad7476_if is
generic
(
	g_prescaler : natural := 1
);
port
(
	clock	: in	std_ulogic;
	reset	: in	std_ulogic;
	
	-- To the adc7476
	sclk		: out	std_ulogic;
	n_cs		: out	std_ulogic;
	sdata		: in	std_ulogic;
	
	-- To the internal logic
	
	data		: out	std_ulogic_vector(11 downto 0);
	data_valid	: out	std_ulogic
);
end ad7476_if;

architecture rtl of ad7476_if is
	signal cs			: std_ulogic;
	signal c_counter	: unsigned((2**g_prescaler)-1 downto 0);
	signal b_counter	: unsigned(4 downto 0);
	
	signal sclk_int		: std_ulogic;
	signal sclk_old		: std_ulogic;
	signal sample		: std_ulogic;
begin

-- Internal to external signal mapping
n_cs <= not cs;
sclk <= sclk_int;

clock_prescale: process(reset, clock)
begin
	if reset = '1' then
		c_counter <= (others => '0');
	elsif rising_edge(clock) then
		c_counter <= c_counter + 1;
	end if;
end process;

sclk_int <= c_counter(c_counter'left);

bit_counter: process(reset, clock)
begin
	if reset = '1' then
		b_counter <= (others => '0');
	elsif rising_edge(clock) then
		if c_counter = 0 then
			b_counter <= b_counter + 1;
			if b_counter = 19 then
				b_counter <= (others => '0');
			end if;
		end if;
	end if;
end process;

sclk_rising: process(reset, clock)
begin
	if reset = '1' then
		sclk_old <= '0';
	elsif rising_edge(clock) then
		sclk_old <= sclk_int;
	end if;
end process;
sample <= sclk_int and not sclk_old;

sample_gen: process(reset, clock)
begin
	if reset = '1' then
		data	<= (others => '0');
		data_valid	<= '0';
	elsif rising_edge(clock) then
		data_valid <= '0';

		if sample = '1' then
			case to_integer(b_counter) is
				when 5+0 to 5+10 =>
					data(11-to_integer(b_counter-5)) <= sdata;
				when 5+11 =>
					data(11-to_integer(b_counter-5)) <= sdata;
					data_valid <= '1';
				when others =>
			end case;
		end if;
	end if;
end process;

cs_gen: process(b_counter)
begin
	cs <= '0';
	if b_counter < 15 then
		cs <= '1';
	end if;
end process;

end rtl;