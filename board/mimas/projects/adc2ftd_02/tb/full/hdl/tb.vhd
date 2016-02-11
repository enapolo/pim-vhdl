-----------------------------------------------------------------------------
-- file			: tb.vhd
--
-- brief		: Test bench
-- author(s)	: marc at pignat dot org
-----------------------------------------------------------------------------
-- Copyright 2015,2016 Marc Pignat
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
-- 		http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- See the License for the specific language governing permissions and
-- limitations under the License.
-----------------------------------------------------------------------------

library ieee;
	use ieee.std_logic_1164.all;
	use ieee.numeric_std.all;

entity tb is
generic
(
	g_parallel : natural := 4
);
end tb;

architecture bhv of tb is
	signal reset			: std_ulogic;

	signal clock			: std_ulogic;
	signal adbus			: std_logic_vector(7 downto 0);
	signal reset_n			: std_ulogic;
	signal txe_n			: std_ulogic;
	signal rxf_n			: std_ulogic;
	signal wr_n				: std_ulogic;
	signal rd_n				: std_ulogic;
	signal siwu				: std_ulogic;
	signal oe_n				: std_ulogic;
	signal suspend_n		: std_ulogic;

	-- ADCs
	signal sclk				: std_ulogic;
	signal n_cs				: std_ulogic;
	signal sdata			: std_ulogic_vector(g_parallel-1 downto 0);
begin

i_top: entity work.top
generic map
(
	g_parallel	=> g_parallel
)
port map
(
	-- Mimas
	led				=> open,

	-- FT2232h
	clkout			=> clock,
	adbus			=> adbus,
	reset_n			=> reset_n,
	txe_n			=> txe_n,
	rxf_n			=> rxf_n,
	wr_n			=> wr_n,
	rd_n			=> rd_n,
	siwu			=> siwu,
	oe_n			=> oe_n,
	suspend_n		=> suspend_n,

	-- ADCs
	sclk			=> sclk,
	n_cs			=> n_cs,
	sdata			=> sdata,

	reset			=> reset
);

i_ft245_sim: entity work.ft245_sync_sim
port map
(
	adbus			=> adbus,
	rxf_n			=> rxf_n,
	txe_n			=> txe_n,
	rd_n			=> rd_n,
	wr_n			=> wr_n,
	clock			=> clock,
	oe_n			=> oe_n,
	siwu			=> siwu,
	reset_n			=> reset_n,
	suspend_n		=> suspend_n,

	d_data_out		=> open,
	d_data_in		=> x"00",
	d_data_write	=> '0',
	d_data_full		=> open
);

i_ad7476_parallel_sim: entity work.ad7476_parallel_sim
generic map
(
	g_parallel	=> g_parallel
)
port map
(
	sclk			=> sclk,
	n_cs			=> n_cs,
	sdata			=> sdata
);

i_reset: entity work.reset
port map
(
	reset	=> reset,
	clock	=> clock
);

i_clock: entity work.clock
generic map
(
	frequency => 60.0e6
)
port map
(
	clock	=> clock
);

end bhv;
