-----------------------------------------------------------------------------
-- file		: clock.vhd 
--
-- brief		: Simulate a FT2232H in FT245 Synchronous fifo mode
-- author(s)	: marc at pignat dot org
-- license		: The MIT License (MIT) (http://opensource.org/licenses/MIT)
--				  Copyright (c) 2015 Marc Pignat
-----------------------------------------------------------------------------

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity ft245_sync_sim is
	port
	(
		adbus		: inout	std_logic_vector(7 downto 0);
		rxf_n		: out	std_ulogic;
		txe_n		: out	std_ulogic;
		rd_n		: in	std_ulogic;
		wr_n		: in	std_ulogic;
		clkout		: out	std_ulogic;
		oe_n		: in	std_ulogic;
		siwu		: in	std_ulogic;
		reset_n		: in	std_ulogic;
		suspend_n	: out	std_ulogic;
		
		d_data_out	: out	std_ulogic_vector(7 downto 0);
		d_data_in	: in	std_ulogic_vector(7 downto 0);
		d_data_write: in	std_ulogic
	);
end ft245_sync_sim ;

architecture bhv of ft245_sync_sim is
	signal reset		: std_ulogic;
	signal oe			: std_ulogic;
	signal data_in		: std_ulogic_vector(adbus'range);
	signal clock		: std_ulogic;
	signal tx_full		: std_ulogic;
	signal tx_full_old	: std_ulogic;
	signal tx_counter	: unsigned(3 downto 0);
begin

reset		<= not reset_n;
oe			<= not oe_n;
clkout		<= clock;
rxf_n		<= not d_data_write;
txe_n		<= tx_full;
suspend_n	<= '0';

tx_counter_gen: process(reset, clock)
begin
	if reset = '1' then
		tx_counter <= (others => '0');
	elsif rising_edge(clock) then
		tx_counter <= tx_counter + 1;
	end if;
end process;
tx_full <= '1' when tx_counter = 0 else '0';

debug_out: process(reset, clock)
begin
	if reset = '1' then
		d_data_out <= (others => '-');
		tx_full_old <= '0';
	elsif rising_edge(clock) then
		tx_full_old <= tx_full;
		d_data_out <= (others => '-');
		if tx_full = '0' and wr_n = '0' then
			d_data_out <= std_ulogic_vector(adbus);
		end if;
	end if;	
end process;

debug_in: process(reset, clock)
begin
	if reset = '1' then
		data_in <= d_data_in;
	elsif rising_edge(clock) then
		data_in <= d_data_in;
	end if;	
end process;

adbus <= std_logic_vector(data_in) when oe = '1' else (others => 'Z');

i_clock: entity work.clock
	generic map
	(
		frequency => 60.0e6
	)
	port map
	(
		clock	=> clock
	);
	
end architecture bhv;
