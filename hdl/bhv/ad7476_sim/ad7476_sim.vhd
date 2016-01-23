-----------------------------------------------------------------------------
-- file			: ad7476_sim.vhd 
--
-- brief		: ad7476 (for simulation)
-- author(s)	: marc at pignat dot org
-- license		: The MIT License (MIT) (http://opensource.org/licenses/MIT)
--				  Copyright (c) 2015 Marc Pignat
-----------------------------------------------------------------------------

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity ad7476_sim is
port
(
	sclk		: in	std_ulogic;
	n_cs		: in	std_ulogic;
	sdata		: out	std_ulogic
);
end ad7476_sim;

architecture bhv of ad7476_sim is
	alias clock is sclk;
	signal reset	: std_ulogic;
	signal data		: unsigned(11 downto 0);
	signal cs		: std_ulogic;
	signal cs_old	: std_ulogic;
	signal counter	: unsigned(4 downto 0);
begin

cs <= not(n_cs);

gen_data: process(reset, clock)
begin
	if reset = '1' then
		data <= (data'left => '1', others => '0');
	elsif falling_edge(clock) then
		if cs = '1' and cs_old = '0' then
			data <= rotate_left(data, 1);
		end if;
	end if;
end process;

data_out: process(reset, clock)
begin
	if reset = '1' then
		counter <= (others => '0');
		cs_old <= '0';
		sdata <= '0';
	elsif falling_edge(clock) then
		counter <= counter + 1;
		if counter = 19 then
			counter <= counter;
		end if;
		
		cs_old <= cs;
		if cs = '1' and cs_old = '0' then
			counter <= (others => '0');
		end if;
		
		case to_integer(counter) is
			when 3+0 to 3+11 =>
				sdata <= data(11-to_integer(counter-3));
			
			when others =>
				sdata <= '0';
		end case;
		
	end if;
end process;

reset <= '1', '0' after 1 ns;
end architecture bhv;